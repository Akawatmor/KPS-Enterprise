// app/layout.tsx
import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "TodoApp — Big Calendar",
  description: "Todo app with a huge calendar view — Phase 2 on K3s + Woodpecker CI/CD",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}): React.JSX.Element {
  return (
    <html lang="th">
      <head />
      <body>{children}</body>
    </html>
  );
}
