import { ImageResponse } from 'next/og';

export const runtime = 'edge';
export const alt = 'ISOCITY — Metropolis Builder';
export const size = {
  width: 1200,
  height: 630,
};
export const contentType = 'image/png';

// Isometric tile dimensions
const TILE_W = 64;
const TILE_H = 32;

// Convert grid coords to screen position
function gridToScreen(x: number, y: number) {
  return {
    screenX: (x - y) * (TILE_W / 2) + 600, // center in 1200px width
    screenY: (x + y) * (TILE_H / 2) + 80,
  };
}

// Tile component - isometric diamond
function Tile({ x, y, color, borderColor = 'rgba(0,0,0,0.2)' }: { x: number; y: number; color: string; borderColor?: string }) {
  const { screenX, screenY } = gridToScreen(x, y);
  
  return (
    <div
      style={{
        position: 'absolute',
        left: screenX - TILE_W / 2,
        top: screenY,
        width: TILE_W,
        height: TILE_H,
        display: 'flex',
      }}
    >
      <svg width={TILE_W} height={TILE_H} viewBox={`0 0 ${TILE_W} ${TILE_H}`}>
        <polygon
          points={`${TILE_W/2},0 ${TILE_W},${TILE_H/2} ${TILE_W/2},${TILE_H} 0,${TILE_H/2}`}
          fill={color}
          stroke={borderColor}
          strokeWidth="0.5"
        />
      </svg>
    </div>
  );
}

// Road tile with connections
function RoadTile({ x, y, north = false, east = false, south = false, west = false }: { x: number; y: number; north?: boolean; east?: boolean; south?: boolean; west?: boolean }) {
  const { screenX, screenY } = gridToScreen(x, y);
  
  const roadColor = '#4a4a4a';
  const grassColor = '#3d5a35';
  const hw = TILE_W * 0.15;
  const hh = TILE_H * 0.15;
  const center = { x: TILE_W * 0.5, y: TILE_H * 0.5 };
  
  // Build road path segments
  const segments: string[] = [];
  
  if (north) {
    segments.push(`M ${center.x - hw * 0.7} ${center.y - hh * 0.7} L ${TILE_W * 0.25 - hw * 0.5} ${TILE_H * 0.25 - hh * 0.5} L ${TILE_W * 0.25 + hw * 0.5} ${TILE_H * 0.25 + hh * 0.5} L ${center.x + hw * 0.7} ${center.y + hh * 0.7} Z`);
  }
  if (east) {
    segments.push(`M ${center.x + hw * 0.7} ${center.y - hh * 0.7} L ${TILE_W * 0.75 + hw * 0.5} ${TILE_H * 0.25 - hh * 0.5} L ${TILE_W * 0.75 - hw * 0.5} ${TILE_H * 0.25 + hh * 0.5} L ${center.x - hw * 0.7} ${center.y + hh * 0.7} Z`);
  }
  if (south) {
    segments.push(`M ${center.x + hw * 0.7} ${center.y + hh * 0.7} L ${TILE_W * 0.75 + hw * 0.5} ${TILE_H * 0.75 + hh * 0.5} L ${TILE_W * 0.75 - hw * 0.5} ${TILE_H * 0.75 - hh * 0.5} L ${center.x - hw * 0.7} ${center.y - hh * 0.7} Z`);
  }
  if (west) {
    segments.push(`M ${center.x - hw * 0.7} ${center.y + hh * 0.7} L ${TILE_W * 0.25 - hw * 0.5} ${TILE_H * 0.75 + hh * 0.5} L ${TILE_W * 0.25 + hw * 0.5} ${TILE_H * 0.75 - hh * 0.5} L ${center.x + hw * 0.7} ${center.y - hh * 0.7} Z`);
  }
  
  const centerSize = hw * 1.4;
  const centerPath = `M ${center.x} ${center.y - centerSize} L ${center.x + centerSize} ${center.y} L ${center.x} ${center.y + centerSize} L ${center.x - centerSize} ${center.y} Z`;
  
  return (
    <div
      style={{
        position: 'absolute',
        left: screenX - TILE_W / 2,
        top: screenY,
        width: TILE_W,
        height: TILE_H,
        display: 'flex',
      }}
    >
      <svg width={TILE_W} height={TILE_H} viewBox={`0 0 ${TILE_W} ${TILE_H}`}>
        {/* Grass base */}
        <polygon
          points={`${TILE_W/2},0 ${TILE_W},${TILE_H/2} ${TILE_W/2},${TILE_H} 0,${TILE_H/2}`}
          fill={grassColor}
          stroke="#2d4a26"
          strokeWidth="0.5"
        />
        {/* Road segments */}
        {segments.map((d, i) => (
          <path key={i} d={d} fill={roadColor} />
        ))}
        {/* Center */}
        <path d={centerPath} fill={roadColor} />
      </svg>
    </div>
  );
}

// Isometric building box
function Building({ 
  x, y, 
  height, 
  topColor, 
  leftColor, 
  rightColor,
  width = 1,
  depth = 1,
  windowColor,
  roofColor,
}: { 
  x: number; 
  y: number; 
  height: number;
  topColor: string;
  leftColor: string;
  rightColor: string;
  width?: number;
  depth?: number;
  windowColor?: string;
  roofColor?: string;
}) {
  const { screenX, screenY } = gridToScreen(x, y);
  const w = TILE_W * width;
  const h = TILE_H * depth;
  
  // Build SVG viewbox to include building height
  const viewH = h + height;
  
  return (
    <div
      style={{
        position: 'absolute',
        left: screenX - w / 2,
        top: screenY - height,
        width: w,
        height: viewH,
        display: 'flex',
      }}
    >
      <svg width={w} height={viewH} viewBox={`0 0 ${w} ${viewH}`}>
        {/* Left face */}
        <polygon
          points={`0,${h/2} ${w/2},${h} ${w/2},${h + height} 0,${h/2 + height}`}
          fill={leftColor}
        />
        {/* Right face */}
        <polygon
          points={`${w},${h/2} ${w/2},${h} ${w/2},${h + height} ${w},${h/2 + height}`}
          fill={rightColor}
        />
        {/* Top face */}
        <polygon
          points={`${w/2},0 ${w},${h/2} ${w/2},${h} 0,${h/2}`}
          fill={topColor}
        />
        {/* Optional roof */}
        {roofColor && (
          <polygon
            points={`${w/2},-8 ${w * 0.85},${h * 0.35 - 8} ${w/2},${h * 0.7 - 8} ${w * 0.15},${h * 0.35 - 8}`}
            fill={roofColor}
          />
        )}
        {/* Windows on right face */}
        {windowColor && (
          <>
            <rect x={w * 0.55} y={h * 0.4 + height * 0.2} width={w * 0.08} height={height * 0.15} fill={windowColor} />
            <rect x={w * 0.68} y={h * 0.4 + height * 0.2} width={w * 0.08} height={height * 0.15} fill={windowColor} />
            <rect x={w * 0.55} y={h * 0.4 + height * 0.45} width={w * 0.08} height={height * 0.15} fill={windowColor} />
            <rect x={w * 0.68} y={h * 0.4 + height * 0.45} width={w * 0.08} height={height * 0.15} fill={windowColor} />
            <rect x={w * 0.55} y={h * 0.4 + height * 0.7} width={w * 0.08} height={height * 0.15} fill={windowColor} />
            <rect x={w * 0.68} y={h * 0.4 + height * 0.7} width={w * 0.08} height={height * 0.15} fill={windowColor} />
          </>
        )}
      </svg>
    </div>
  );
}

// Tree element
function Tree({ x, y }: { x: number; y: number }) {
  const { screenX, screenY } = gridToScreen(x, y);
  const treeH = 28;
  
  return (
    <div
      style={{
        position: 'absolute',
        left: screenX - TILE_W / 2,
        top: screenY - treeH,
        width: TILE_W,
        height: TILE_H + treeH,
        display: 'flex',
      }}
    >
      <svg width={TILE_W} height={TILE_H + treeH} viewBox={`0 0 ${TILE_W} ${TILE_H + treeH}`}>
        {/* Ground */}
        <polygon
          points={`${TILE_W/2},${treeH} ${TILE_W},${treeH + TILE_H/2} ${TILE_W/2},${treeH + TILE_H} 0,${treeH + TILE_H/2}`}
          fill="#4a7c3f"
          stroke="#2d4a26"
          strokeWidth="0.5"
        />
        {/* Trunk */}
        <rect x={TILE_W/2 - 2} y={treeH - 10} width={4} height={12} fill="#5D4037" />
        {/* Canopy */}
        <ellipse cx={TILE_W/2} cy={treeH - 14} rx={10} ry={14} fill="#2E7D32" />
        <ellipse cx={TILE_W/2} cy={treeH - 16} rx={8} ry={10} fill="#388E3C" />
      </svg>
    </div>
  );
}

// Water tile
function WaterTile({ x, y }: { x: number; y: number }) {
  const { screenX, screenY } = gridToScreen(x, y);
  
  return (
    <div
      style={{
        position: 'absolute',
        left: screenX - TILE_W / 2,
        top: screenY,
        width: TILE_W,
        height: TILE_H,
        display: 'flex',
      }}
    >
      <svg width={TILE_W} height={TILE_H} viewBox={`0 0 ${TILE_W} ${TILE_H}`}>
        <defs>
          <linearGradient id="waterGrad" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stopColor="#2563eb" />
            <stop offset="50%" stopColor="#1d4ed8" />
            <stop offset="100%" stopColor="#1e40af" />
          </linearGradient>
        </defs>
        <polygon
          points={`${TILE_W/2},0 ${TILE_W},${TILE_H/2} ${TILE_W/2},${TILE_H} 0,${TILE_H/2}`}
          fill="url(#waterGrad)"
          stroke="#1e3a8a"
          strokeWidth="0.5"
        />
        <ellipse cx={TILE_W * 0.35} cy={TILE_H * 0.4} rx={4} ry={3} fill="#60a5fa" opacity={0.5} />
        <ellipse cx={TILE_W * 0.65} cy={TILE_H * 0.55} rx={3} ry={2} fill="#93c5fd" opacity={0.4} />
      </svg>
    </div>
  );
}

export default async function Image() {
  // Define the grid layout - 12x10 grid
  const gridSize = { cols: 12, rows: 10 };
  
  // Define what's on each tile
  type TileType = 'grass' | 'road' | 'water' | 'tree' | 'building';
  
  interface GridTile {
    type: TileType;
    roadConnections?: { north: boolean; east: boolean; south: boolean; west: boolean };
    building?: {
      height: number;
      topColor: string;
      leftColor: string;
      rightColor: string;
      windowColor?: string;
      roofColor?: string;
    };
  }
  
  // Initialize grid with grass
  const grid: GridTile[][] = Array(gridSize.rows).fill(null).map(() => 
    Array(gridSize.cols).fill(null).map(() => ({ type: 'grass' as TileType }))
  );
  
  // Add a main road (diagonal through the city)
  const roadPath = [
    [0, 4], [1, 4], [2, 4], [3, 4], [4, 4], [5, 4], [6, 4], [7, 4], [8, 4], [9, 4], [10, 4], [11, 4],
    [4, 0], [4, 1], [4, 2], [4, 3], [4, 5], [4, 6], [4, 7], [4, 8], [4, 9],
    [7, 2], [7, 3], [7, 5], [7, 6], [7, 7],
  ];
  
  roadPath.forEach(([x, y]) => {
    if (x >= 0 && x < gridSize.rows && y >= 0 && y < gridSize.cols) {
      const north = roadPath.some(([rx, ry]) => rx === x - 1 && ry === y);
      const south = roadPath.some(([rx, ry]) => rx === x + 1 && ry === y);
      const east = roadPath.some(([rx, ry]) => rx === x && ry === y - 1);
      const west = roadPath.some(([rx, ry]) => rx === x && ry === y + 1);
      
      grid[x][y] = { 
        type: 'road', 
        roadConnections: { north, east, south, west }
      };
    }
  });
  
  // Add water (small lake in corner)
  const waterTiles = [[8, 8], [8, 9], [9, 8], [9, 9], [8, 10], [9, 10], [10, 9], [10, 10]];
  waterTiles.forEach(([x, y]) => {
    if (x >= 0 && x < gridSize.rows && y >= 0 && y < gridSize.cols) {
      grid[x][y] = { type: 'water' };
    }
  });
  
  // Add trees
  const treeTiles = [[0, 0], [0, 1], [1, 0], [10, 0], [10, 1], [11, 0], [0, 10], [0, 11], [1, 11]];
  treeTiles.forEach(([x, y]) => {
    if (x >= 0 && x < gridSize.rows && y >= 0 && y < gridSize.cols) {
      grid[x][y] = { type: 'tree' };
    }
  });
  
  // Add buildings
  const buildings: Array<{ x: number; y: number; height: number; topColor: string; leftColor: string; rightColor: string; windowColor?: string; roofColor?: string }> = [
    // Residential area (small houses with roofs)
    { x: 1, y: 2, height: 25, topColor: '#FFE082', leftColor: '#FFD54F', rightColor: '#FFECB3', roofColor: '#8D6E63' },
    { x: 2, y: 2, height: 28, topColor: '#BBDEFB', leftColor: '#90CAF9', rightColor: '#E3F2FD', roofColor: '#546E7A' },
    { x: 3, y: 2, height: 25, topColor: '#FFE082', leftColor: '#FFD54F', rightColor: '#FFECB3', roofColor: '#8D6E63' },
    { x: 1, y: 3, height: 30, topColor: '#C5CAE9', leftColor: '#7986CB', rightColor: '#E8EAF6', windowColor: '#FFF59D' },
    { x: 2, y: 3, height: 26, topColor: '#FFE082', leftColor: '#FFD54F', rightColor: '#FFECB3', roofColor: '#6D4C41' },
    { x: 3, y: 3, height: 32, topColor: '#BBDEFB', leftColor: '#90CAF9', rightColor: '#E3F2FD', windowColor: '#FFF59D' },
    
    // Commercial district (taller buildings)
    { x: 5, y: 2, height: 55, topColor: '#BDBDBD', leftColor: '#757575', rightColor: '#E0E0E0', windowColor: '#29B6F6' },
    { x: 6, y: 2, height: 70, topColor: '#00ACC1', leftColor: '#00838F', rightColor: '#4DD0E1', windowColor: '#E0F7FA' },
    { x: 5, y: 3, height: 48, topColor: '#CFD8DC', leftColor: '#90A4AE', rightColor: '#ECEFF1', windowColor: '#BBDEFB' },
    { x: 6, y: 3, height: 62, topColor: '#BDBDBD', leftColor: '#757575', rightColor: '#E0E0E0', windowColor: '#FFF59D' },
    
    // Industrial area
    { x: 8, y: 2, height: 35, topColor: '#6D4C41', leftColor: '#5D4037', rightColor: '#8D6E63' },
    { x: 9, y: 2, height: 30, topColor: '#FFB300', leftColor: '#FF8F00', rightColor: '#FFA000' },
    { x: 8, y: 3, height: 40, topColor: '#546E7A', leftColor: '#455A64', rightColor: '#78909C' },
    
    // More residential on other side
    { x: 1, y: 5, height: 28, topColor: '#FFECB3', leftColor: '#FFE082', rightColor: '#FFF8E1', roofColor: '#8D6E63' },
    { x: 2, y: 5, height: 45, topColor: '#C5CAE9', leftColor: '#7986CB', rightColor: '#E8EAF6', windowColor: '#FFF59D' },
    { x: 3, y: 5, height: 25, topColor: '#FFE082', leftColor: '#FFD54F', rightColor: '#FFECB3', roofColor: '#5D4037' },
    { x: 1, y: 6, height: 50, topColor: '#BBDEFB', leftColor: '#90CAF9', rightColor: '#E3F2FD', windowColor: '#BBDEFB' },
    { x: 2, y: 6, height: 30, topColor: '#FFE082', leftColor: '#FFD54F', rightColor: '#FFECB3', roofColor: '#8D6E63' },
    { x: 3, y: 6, height: 38, topColor: '#C5CAE9', leftColor: '#7986CB', rightColor: '#E8EAF6', windowColor: '#FFF59D' },
    
    // Downtown high-rises
    { x: 5, y: 5, height: 80, topColor: '#00ACC1', leftColor: '#00838F', rightColor: '#4DD0E1', windowColor: '#E0F7FA' },
    { x: 6, y: 5, height: 65, topColor: '#BDBDBD', leftColor: '#757575', rightColor: '#E0E0E0', windowColor: '#29B6F6' },
    { x: 5, y: 6, height: 58, topColor: '#CFD8DC', leftColor: '#90A4AE', rightColor: '#ECEFF1', windowColor: '#FFF59D' },
    { x: 6, y: 6, height: 72, topColor: '#00ACC1', leftColor: '#00838F', rightColor: '#4DD0E1', windowColor: '#80DEEA' },
    
    // Park buildings (low)
    { x: 8, y: 5, height: 22, topColor: '#81C784', leftColor: '#66BB6A', rightColor: '#A5D6A7' },
    { x: 9, y: 5, height: 20, topColor: '#81C784', leftColor: '#66BB6A', rightColor: '#A5D6A7' },
    
    // Services
    { x: 1, y: 8, height: 35, topColor: '#D32F2F', leftColor: '#C62828', rightColor: '#E53935' }, // Fire station
    { x: 2, y: 8, height: 38, topColor: '#1976D2', leftColor: '#1565C0', rightColor: '#2196F3' }, // Police
    { x: 3, y: 8, height: 50, topColor: '#BDBDBD', leftColor: '#9E9E9E', rightColor: '#E0E0E0', windowColor: '#E3F2FD' }, // Hospital
  ];
  
  // Sort elements by render order (back to front: higher x+y first for tiles, then buildings by position)
  const renderOrder: Array<{ type: string; x: number; y: number; data?: GridTile | typeof buildings[0] }> = [];
  
  // Add tiles to render order
  for (let x = 0; x < gridSize.rows; x++) {
    for (let y = 0; y < gridSize.cols; y++) {
      renderOrder.push({ type: 'tile', x, y, data: grid[x][y] });
    }
  }
  
  // Add buildings to render order
  buildings.forEach((b) => {
    renderOrder.push({ type: 'building', x: b.x, y: b.y, data: b });
  });
  
  // Sort by depth (x + y), then by type (tiles first, then buildings)
  renderOrder.sort((a, b) => {
    const depthA = a.x + a.y;
    const depthB = b.x + b.y;
    if (depthA !== depthB) return depthA - depthB;
    if (a.type === 'tile' && b.type === 'building') return -1;
    if (a.type === 'building' && b.type === 'tile') return 1;
    return 0;
  });

  return new ImageResponse(
    (
      <div
        style={{
          background: 'linear-gradient(135deg, #0f1219 0%, #1a1f2e 50%, #0f1219 100%)',
          width: '100%',
          height: '100%',
          display: 'flex',
          flexDirection: 'column',
          position: 'relative',
          overflow: 'hidden',
        }}
      >
        {/* Decorative gradient overlay */}
        <div
          style={{
            position: 'absolute',
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            background: 'radial-gradient(ellipse at 50% 30%, rgba(212,175,55,0.1) 0%, transparent 50%)',
            display: 'flex',
          }}
        />
        
        {/* Title */}
        <div
          style={{
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            paddingTop: 32,
            zIndex: 10,
          }}
        >
          <div
            style={{
              fontSize: 56,
              fontWeight: 800,
              letterSpacing: '0.15em',
              background: 'linear-gradient(180deg, #D4AF37 0%, #F5E6A3 50%, #D4AF37 100%)',
              backgroundClip: 'text',
              color: 'transparent',
              display: 'flex',
            }}
          >
            ISOCITY
          </div>
          <div
            style={{
              fontSize: 20,
              color: '#9CA3AF',
              letterSpacing: '0.3em',
              marginTop: 4,
              display: 'flex',
            }}
          >
            METROPOLIS BUILDER
          </div>
        </div>
        
        {/* Isometric city scene */}
        <div
          style={{
            position: 'absolute',
            top: 0,
            left: 0,
            width: '100%',
            height: '100%',
            display: 'flex',
          }}
        >
          {renderOrder.map((item, idx) => {
            if (item.type === 'tile') {
              const tile = item.data as GridTile;
              if (tile.type === 'grass') {
                return <Tile key={idx} x={item.x} y={item.y} color="#4a7c3f" borderColor="#2d4a26" />;
              }
              if (tile.type === 'road') {
                const rc = tile.roadConnections || { north: false, east: false, south: false, west: false };
                return <RoadTile key={idx} x={item.x} y={item.y} {...rc} />;
              }
              if (tile.type === 'water') {
                return <WaterTile key={idx} x={item.x} y={item.y} />;
              }
              if (tile.type === 'tree') {
                return <Tree key={idx} x={item.x} y={item.y} />;
              }
            }
            if (item.type === 'building') {
              const b = item.data as typeof buildings[0];
              return (
                <Building
                  key={idx}
                  x={b.x}
                  y={b.y}
                  height={b.height}
                  topColor={b.topColor}
                  leftColor={b.leftColor}
                  rightColor={b.rightColor}
                  windowColor={b.windowColor}
                  roofColor={b.roofColor}
                />
              );
            }
            return null;
          })}
        </div>
        
        {/* Bottom tagline */}
        <div
          style={{
            position: 'absolute',
            bottom: 24,
            left: 0,
            right: 0,
            display: 'flex',
            justifyContent: 'center',
            alignItems: 'center',
            gap: 16,
          }}
        >
          <div
            style={{
              fontSize: 16,
              color: '#6B7280',
              display: 'flex',
            }}
          >
            Build your gleaming metropolis
          </div>
          <div
            style={{
              width: 4,
              height: 4,
              borderRadius: '50%',
              background: '#D4AF37',
              display: 'flex',
            }}
          />
          <div
            style={{
              fontSize: 16,
              color: '#6B7280',
              display: 'flex',
            }}
          >
            Zone districts
          </div>
          <div
            style={{
              width: 4,
              height: 4,
              borderRadius: '50%',
              background: '#D4AF37',
              display: 'flex',
            }}
          />
          <div
            style={{
              fontSize: 16,
              color: '#6B7280',
              display: 'flex',
            }}
          >
            Manage resources
          </div>
        </div>
      </div>
    ),
    {
      ...size,
    }
  );
}
