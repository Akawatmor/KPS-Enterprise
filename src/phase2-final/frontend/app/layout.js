import "./globals.css";

export const metadata = {
  title: "TodoApp — Big Calendar",
  description: "Todo app with a huge calendar view — Phase 2 on K3s + Woodpecker CI/CD",
};

export default function RootLayout({ children }) {
  return (
    <html lang="th">
      <head />
      <body>{children}</body>
    </html>
  );
}
