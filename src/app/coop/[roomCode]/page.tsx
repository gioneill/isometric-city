import CoopClientPage from './CoopClientPage';

export const dynamicParams = false;

export async function generateStaticParams() {
  // Required for `output: 'export'`; return no paths so this route is not emitted in the bundle build.
  return [];
}

export default async function Page({ params }: { params: Promise<{ roomCode: string }> }) {
  const resolved = await params;
  return <CoopClientPage roomCode={resolved.roomCode} />;
}
