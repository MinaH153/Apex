'use client'

import { createClient } from '@/lib/supabase/client'
import AuthButton from '@/components/AuthButton'
import { useRouter } from 'next/navigation'
import { useCallback, useEffect, useRef, useState } from 'react'

type FileRow = {
  id: string
  owner_id: string
  name: string
  path: string
  size: number | null
  mime_type: string | null
  created_at: string
}

const MAX_FILE_SIZE = 50 * 1024 * 1024 // 50 MB

/** Map common Supabase/storage error messages to user-friendly text. */
function friendlyFileError(message: string): string {
  if (message.includes('The resource already exists') || message.includes('Duplicate') || message.includes('already exists')) {
    return 'A file with that name already exists. Please rename the file and try again.'
  }
  if (message.includes('Payload too large') || message.includes('exceeded the maximum')) {
    return 'File exceeds the 50 MB upload limit.'
  }
  if (message.includes('Not authenticated') || message.includes('not authenticated') || message.includes('JWT expired') || message.includes('Invalid JWT')) {
    return 'auth_redirect'
  }
  if (message.includes('Permission denied') || message.includes('policy')) {
    return 'You do not have permission to perform this action.'
  }
  return message
}

export default function FilesPage() {
  const [files, setFiles] = useState<FileRow[]>([])
  const [loading, setLoading] = useState(true)
  const [uploading, setUploading] = useState(false)
  const [uploadFileName, setUploadFileName] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [successMessage, setSuccessMessage] = useState<string | null>(null)
  const successTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  const fileInputRef = useRef<HTMLInputElement>(null)
  const router = useRouter()
  const supabase = createClient()

  const redirectToAuth = useCallback(() => {
    router.push('/auth')
  }, [router])

  const fetchFiles = useCallback(async () => {
    try {
      setLoading(true)
      setError(null)

      const {
        data: { user },
      } = await supabase.auth.getUser()
      if (!user) {
        redirectToAuth()
        return
      }

      const { data, error: fetchError } = await supabase
        .from('files')
        .select('*')
        .eq('owner_id', user.id)
        .order('created_at', { ascending: false })

      if (fetchError) throw fetchError

      setFiles(data || [])
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'Failed to load files.'
      const friendly = friendlyFileError(message)
      if (friendly === 'auth_redirect') {
        redirectToAuth()
        return
      }
      setError(friendly)
    } finally {
      setLoading(false)
    }
  }, [supabase, redirectToAuth])

  // Auth check + initial fetch
  useEffect(() => {
    const checkAuthAndFetchFiles = async () => {
      const {
        data: { user },
      } = await supabase.auth.getUser()

      if (!user) {
        redirectToAuth()
        return
      }

      await fetchFiles()
    }

    checkAuthAndFetchFiles()
  }, [supabase, redirectToAuth, fetchFiles])

  // Realtime subscription for live updates
  useEffect(() => {
    let channel: ReturnType<typeof supabase.channel> | null = null

    const setupRealtime = async () => {
      const {
        data: { user },
      } = await supabase.auth.getUser()

      if (!user) return

      channel = supabase
        .channel('files-realtime')
        .on(
          'postgres_changes',
          {
            event: 'INSERT',
            schema: 'public',
            table: 'files',
            filter: `owner_id=eq.${user.id}`,
          },
          (payload) => {
            const newFile = payload.new as FileRow
            // WP3: Deduplicate by id to prevent double entries
            setFiles((prev) => {
              if (prev.some((f) => f.id === newFile.id)) return prev
              return [newFile, ...prev]
            })
          }
        )
        .on(
          'postgres_changes',
          {
            event: 'DELETE',
            schema: 'public',
            table: 'files',
            filter: `owner_id=eq.${user.id}`,
          },
          (payload) => {
            // WP3: payload.old contains the deleted row with at least the id
            const deletedId = (payload.old as { id?: string })?.id
            if (deletedId) {
              setFiles((prev) => prev.filter((f) => f.id !== deletedId))
            }
          }
        )
        .subscribe((status) => {
          // WP3: Reconnection handling - refetch when channel reconnects
          if (status === 'CHANNEL_ERROR') {
            // On error, attempt to refetch full list for consistency
            fetchFiles()
          }
        })
    }

    setupRealtime()

    return () => {
      if (channel) {
        supabase.removeChannel(channel)
      }
    }
  }, [supabase, fetchFiles])

  // Cleanup success timer on unmount
  useEffect(() => {
    return () => {
      if (successTimerRef.current) {
        clearTimeout(successTimerRef.current)
      }
    }
  }, [])

  const showSuccess = (message: string) => {
    if (successTimerRef.current) {
      clearTimeout(successTimerRef.current)
    }
    setSuccessMessage(message)
    successTimerRef.current = setTimeout(() => {
      setSuccessMessage(null)
      successTimerRef.current = null
    }, 3000)
  }

  const handleDelete = async (fileRecord: FileRow) => {
    setError(null)
    try {
      const { error: storageError } = await supabase.storage
        .from('files')
        .remove([fileRecord.path])
      if (storageError) throw storageError

      const { error: dbError } = await supabase
        .from('files')
        .delete()
        .eq('id', fileRecord.id)
      if (dbError) throw dbError

      // Realtime will update the list automatically
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'Failed to delete file.'
      const friendly = friendlyFileError(message)
      if (friendly === 'auth_redirect') {
        redirectToAuth()
        return
      }
      setError(friendly)
    }
  }

  const handleFileUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return

    // WP2: Client-side file size check
    if (file.size > MAX_FILE_SIZE) {
      setError('File exceeds the 50 MB upload limit.')
      e.target.value = ''
      return
    }

    try {
      setUploading(true)
      setUploadFileName(file.name)
      setError(null)

      const {
        data: { user },
      } = await supabase.auth.getUser()
      if (!user) {
        redirectToAuth()
        return
      }

      // Upload to storage: {user_id}/{filename}
      const filePath = `${user.id}/${file.name}`
      const { error: uploadError } = await supabase.storage
        .from('files')
        .upload(filePath, file, {
          upsert: false,
        })

      if (uploadError) throw uploadError

      // Insert metadata into public.files
      const { error: insertError } = await supabase.from('files').insert({
        owner_id: user.id,
        name: file.name,
        path: filePath,
        size: file.size,
        mime_type: file.type || null,
      })

      if (insertError) throw insertError

      // WP3: Do NOT refetch; rely on realtime INSERT event for list update
      // WP2: Show success toast
      showSuccess(`"${file.name}" uploaded successfully.`)

      // Clear input
      e.target.value = ''
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'Upload failed.'
      const friendly = friendlyFileError(message)
      if (friendly === 'auth_redirect') {
        redirectToAuth()
        return
      }
      setError(friendly)
      e.target.value = ''
    } finally {
      setUploading(false)
      setUploadFileName(null)
    }
  }

  const formatBytes = (bytes: number | null) => {
    if (!bytes) return 'Unknown'
    const k = 1024
    const sizes = ['Bytes', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i]
  }

  const formatDate = (dateStr: string) => {
    return new Date(dateStr).toLocaleString()
  }

  if (loading) {
    return (
      <div style={{ padding: '40px', textAlign: 'center' }}>
        <div style={{ display: 'inline-block', width: '24px', height: '24px', border: '3px solid #e5e7eb', borderTop: '3px solid #0070f3', borderRadius: '50%', animation: 'spin 0.8s linear infinite' }} />
        <p style={{ marginTop: '12px', color: '#666' }}>Loading files...</p>
        <style>{`@keyframes spin { to { transform: rotate(360deg); } }`}</style>
      </div>
    )
  }

  return (
    <div style={{ padding: '40px', maxWidth: '1200px', margin: '0 auto' }}>
      <div
        style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          marginBottom: '30px',
        }}
      >
        <h1 style={{ margin: 0 }}>My Files</h1>
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          <input
            type="file"
            onChange={handleFileUpload}
            disabled={uploading}
            id="file-upload"
            ref={fileInputRef}
            style={{ display: 'none' }}
          />
          <label
            htmlFor="file-upload"
            style={{
              padding: '10px 20px',
              backgroundColor: uploading ? '#ccc' : '#0070f3',
              color: 'white',
              borderRadius: '4px',
              cursor: uploading ? 'not-allowed' : 'pointer',
              display: 'inline-block',
            }}
          >
            {uploading ? 'Uploading...' : 'Upload File'}
          </label>
          <a href="/" style={{ color: '#0070f3', textDecoration: 'underline' }}>Home</a>
          <AuthButton />
        </div>
      </div>

      {/* WP2: Upload progress banner */}
      {uploading && uploadFileName && (
        <div
          style={{
            padding: '12px 16px',
            backgroundColor: '#eff6ff',
            color: '#1d4ed8',
            borderRadius: '4px',
            marginBottom: '16px',
            display: 'flex',
            alignItems: 'center',
            gap: '12px',
            border: '1px solid #bfdbfe',
          }}
        >
          <div style={{ display: 'inline-block', width: '18px', height: '18px', border: '2px solid #bfdbfe', borderTop: '2px solid #1d4ed8', borderRadius: '50%', animation: 'spin 0.8s linear infinite', flexShrink: 0 }} />
          <span>Uploading &ldquo;{uploadFileName}&rdquo;...</span>
          <style>{`@keyframes spin { to { transform: rotate(360deg); } }`}</style>
        </div>
      )}

      {/* WP2: Success toast */}
      {successMessage && (
        <div
          style={{
            padding: '12px 16px',
            backgroundColor: '#f0fdf4',
            color: '#15803d',
            borderRadius: '4px',
            marginBottom: '16px',
            border: '1px solid #bbf7d0',
          }}
        >
          {successMessage}
        </div>
      )}

      {/* WP1: Error banner with Retry button */}
      {error && (
        <div
          style={{
            padding: '12px 16px',
            backgroundColor: '#fef2f2',
            color: '#dc2626',
            borderRadius: '4px',
            marginBottom: '20px',
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center',
            border: '1px solid #fecaca',
          }}
        >
          <span>{error}</span>
          <button
            onClick={() => {
              setError(null)
              fetchFiles()
            }}
            style={{
              padding: '4px 12px',
              fontSize: '13px',
              backgroundColor: '#dc2626',
              color: 'white',
              border: 'none',
              borderRadius: '4px',
              cursor: 'pointer',
              flexShrink: 0,
              marginLeft: '12px',
            }}
          >
            Retry
          </button>
        </div>
      )}

      {files.length === 0 ? (
        <div
          style={{
            textAlign: 'center',
            padding: '60px 20px',
            color: '#666',
            border: '2px dashed #ddd',
            borderRadius: '8px',
          }}
        >
          <p style={{ fontSize: '18px', marginBottom: '8px' }}>No files yet</p>
          <p style={{ fontSize: '14px', color: '#999' }}>
            Upload your first file to get started
          </p>
        </div>
      ) : (
        <table
          style={{
            width: '100%',
            borderCollapse: 'collapse',
            border: '1px solid #ddd',
          }}
        >
          <thead>
            <tr style={{ backgroundColor: '#f9fafb' }}>
              <th
                style={{
                  padding: '12px',
                  textAlign: 'left',
                  borderBottom: '2px solid #ddd',
                }}
              >
                Name
              </th>
              <th
                style={{
                  padding: '12px',
                  textAlign: 'left',
                  borderBottom: '2px solid #ddd',
                }}
              >
                Size
              </th>
              <th
                style={{
                  padding: '12px',
                  textAlign: 'left',
                  borderBottom: '2px solid #ddd',
                }}
              >
                Type
              </th>
              <th
                style={{
                  padding: '12px',
                  textAlign: 'left',
                  borderBottom: '2px solid #ddd',
                }}
              >
                Uploaded
              </th>
              <th
                style={{
                  padding: '12px',
                  textAlign: 'left',
                  borderBottom: '2px solid #ddd',
                  width: '80px',
                }}
              ></th>
            </tr>
          </thead>
          <tbody>
            {files.map((file) => (
              <tr key={file.id} style={{ borderBottom: '1px solid #eee' }}>
                <td style={{ padding: '12px' }}>{file.name}</td>
                <td style={{ padding: '12px' }}>{formatBytes(file.size)}</td>
                <td style={{ padding: '12px', fontSize: '14px', color: '#666' }}>
                  {file.mime_type || 'Unknown'}
                </td>
                <td style={{ padding: '12px', fontSize: '14px', color: '#666' }}>
                  {formatDate(file.created_at)}
                </td>
                <td style={{ padding: '12px' }}>
                  <button
                    onClick={() => handleDelete(file)}
                    style={{
                      padding: '4px 12px',
                      fontSize: '13px',
                      backgroundColor: '#fee2e2',
                      color: '#dc2626',
                      border: '1px solid #fca5a5',
                      borderRadius: '4px',
                      cursor: 'pointer',
                    }}
                  >
                    Delete
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  )
}
