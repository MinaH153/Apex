export default function Home() {
  return (
    <main style={{ padding: '40px', textAlign: 'center' }}>
      <h1>Hello, Apex</h1>
      <p style={{ marginTop: '20px' }}>
        <a
          href="/files"
          style={{
            padding: '12px 24px',
            backgroundColor: '#0070f3',
            color: 'white',
            textDecoration: 'none',
            borderRadius: '4px',
            display: 'inline-block',
          }}
        >
          Go to Files
        </a>
      </p>
    </main>
  );
}
