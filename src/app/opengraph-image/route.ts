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
  
  // Redirect to the static image
  return NextResponse.redirect(`${baseUrl}/games/${randomFile}`, { status: 302 });
}
