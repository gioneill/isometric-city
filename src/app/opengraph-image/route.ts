import { NextRequest, NextResponse } from 'next/server';

// Static list of game screenshots
const GAME_IMAGES = [
  'IMG_6902.PNG',
  'IMG_6903.PNG',
  'IMG_6904.PNG',
  'IMG_6906.PNG',
  'IMG_6907.PNG',
  'IMG_6908.PNG',
  'IMG_6909.PNG',
  'IMG_6910.PNG',
  'IMG_6911.PNG',
];

export async function GET(request: NextRequest) {
  // Pick a random image
  const randomFile = GAME_IMAGES[Math.floor(Math.random() * GAME_IMAGES.length)];
  
  // Get the base URL from the request
  const baseUrl = new URL(request.url).origin;
  
  // Fetch the image from the public folder
  const imageResponse = await fetch(`${baseUrl}/games/${randomFile}`);
  
  if (!imageResponse.ok) {
    return new NextResponse('Image not found', { status: 404 });
  }
  
  const imageBuffer = await imageResponse.arrayBuffer();
  
  return new NextResponse(imageBuffer, {
    headers: {
      'Content-Type': 'image/png',
      'Cache-Control': 'public, max-age=3600',
    },
  });
}
