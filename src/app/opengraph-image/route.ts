import { readFile, readdir } from 'fs/promises';
import { join } from 'path';
import { NextResponse } from 'next/server';

export async function GET() {
  const gamesDir = join(process.cwd(), 'public', 'games');
  
  // Get all PNG files in the games directory
  const files = await readdir(gamesDir);
  const pngFiles = files.filter(f => f.toLowerCase().endsWith('.png'));
  
  if (pngFiles.length === 0) {
    return new NextResponse('No images found', { status: 404 });
  }
  
  // Pick a random image
  const randomFile = pngFiles[Math.floor(Math.random() * pngFiles.length)];
  const imagePath = join(gamesDir, randomFile);
  
  const imageBuffer = await readFile(imagePath);
  
  return new NextResponse(imageBuffer, {
    headers: {
      'Content-Type': 'image/png',
      'Cache-Control': 'no-cache, no-store, must-revalidate',
    },
  });
}
