import type { Metadata, Viewport } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

const SITE_URL = "https://sightmk.vercel.app";
const SITE_NAME = "Sight";
const TITLE = "Sight — Your files, sorted by meaning";
const DESCRIPTION =
  "Sight keeps a folder organized — by building meaning vectors of files and matching them against rules you write in plain language. Everything runs on-device on your Mac. No cloud, no telemetry, no accounts. Free and open source (Apache-2.0). Made by Miras Kustaibek.";

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: {
    default: TITLE,
    template: "%s · Sight",
  },
  description: DESCRIPTION,
  applicationName: SITE_NAME,
  authors: [{ name: "Miras Kustaibek", url: "https://miraskustaibek.me" }],
  creator: "Miras Kustaibek",
  publisher: "Miras Kustaibek",
  keywords: [
    "Sight",
    "macOS file organizer",
    "on-device AI",
    "local language model",
    "file sorting",
    "semantic file organization",
    "neural engine",
    "privacy-first",
    "open source",
    "Miras Kustaibek",
    "Mac app",
    "Downloads folder",
  ],
  category: "productivity",
  alternates: {
    canonical: "/",
  },
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      "max-image-preview": "large",
      "max-snippet": -1,
      "max-video-preview": -1,
    },
  },
  openGraph: {
    type: "website",
    locale: "en_US",
    url: "/",
    siteName: SITE_NAME,
    title: TITLE,
    description: DESCRIPTION,
    images: [
      {
        url: "/opengraph-image",
        width: 1200,
        height: 630,
        alt: "Sight — Your files, sorted by meaning",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: TITLE,
    description: DESCRIPTION,
    images: ["/opengraph-image"],
    creator: "@mirasawe",
  },
  icons: {
    icon: [
      { url: "/favicon.ico", sizes: "32x32" },
      { url: "/icon.png", sizes: "512x512", type: "image/png" },
    ],
    apple: [{ url: "/apple-icon.png", sizes: "180x180", type: "image/png" }],
    shortcut: ["/favicon.ico"],
  },
  manifest: "/manifest.webmanifest",
  other: {
    "apple-mobile-web-app-title": SITE_NAME,
    "application-name": SITE_NAME,
  },
};

export const viewport: Viewport = {
  themeColor: [
    { media: "(prefers-color-scheme: dark)", color: "#000000" },
    { media: "(prefers-color-scheme: light)", color: "#ffffff" },
  ],
  width: "device-width",
  initialScale: 1,
};

const themeInit = `
try {
  var t = localStorage.getItem('sight-theme');
  if (!t) t = window.matchMedia('(prefers-color-scheme: light)').matches ? 'light' : 'dark';
  document.documentElement.dataset.theme = t;
} catch (e) {}
`;

const jsonLd = {
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  name: "Sight",
  description: DESCRIPTION,
  applicationCategory: "ProductivityApplication",
  operatingSystem: "macOS",
  url: SITE_URL,
  image: `${SITE_URL}/opengraph-image`,
  author: {
    "@type": "Person",
    name: "Miras Kustaibek",
    url: "https://miraskustaibek.me",
  },
  creator: {
    "@type": "Person",
    name: "Miras Kustaibek",
  },
  offers: {
    "@type": "Offer",
    price: "0",
    priceCurrency: "USD",
  },
  license: "https://www.apache.org/licenses/LICENSE-2.0",
  isAccessibleForFree: true,
  inLanguage: "en",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html
      lang="en"
      className={`${geistSans.variable} ${geistMono.variable}`}
      suppressHydrationWarning
    >
      <head>
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
        />
      </head>
      <body className="bg-paper text-primary antialiased">
        <script dangerouslySetInnerHTML={{ __html: themeInit }} />
        {children}
      </body>
    </html>
  );
}
