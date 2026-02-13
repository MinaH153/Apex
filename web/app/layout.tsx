import type { Metadata } from "next";
import "./globals.css";
import AuthButton from "@/components/AuthButton";

export const metadata: Metadata = {
  title: "Apex",
  description: "Apex application",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>
        <nav style={{ padding: '16px', borderBottom: '1px solid #e5e7eb', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <a href="/" style={{ fontSize: '20px', fontWeight: 'bold', textDecoration: 'none', color: '#000' }}>Apex</a>
          <AuthButton />
        </nav>
        {children}
      </body>
    </html>
  );
}
