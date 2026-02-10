import CoopClientPage from './CoopClientPage';

export const dynamicParams = false;

export async function generateStaticParams() {
  return [];
}

export default async function Page({ params }: { params: Promise<{ roomCode: string }> }) {
  const resolved = await params;
  return <CoopClientPage roomCode={resolved.roomCode} />;
}
