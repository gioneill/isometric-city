import type { Metadata } from 'next';

interface Props {
  params: Promise<{ roomCode: string }>;
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { roomCode } = await params;
  const code = roomCode.toUpperCase();
  
  const title = `Join co-op ${code}`;
  const fullTitle = `ISOCITY — ${title}`;
  const description = `You've been invited to build a city together! Join room ${code} to start playing.`;

  return {
    title,
    description,
    openGraph: {
      title: fullTitle,
      description,
      images: ['/opengraph-image.png'],
    },
    twitter: {
      title: fullTitle,
      description,
      images: ['/opengraph-image.png'],
    },
  };
}

export default function CoopRoomLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return children;
}
