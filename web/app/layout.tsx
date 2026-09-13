import "./globals.css";

export const metadata = {
  title: "Personal Coach — Executive Function",
  description: "A low-friction executive-function companion for starting, focusing and recovering.",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en"><body>{children}</body></html>;
}
