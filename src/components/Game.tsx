'use client';

import React, { useRef, useState, useCallback, useEffect, useMemo } from 'react';
import { useGame } from '@/context/GameContext';
import { Budget, GameState, Tool, TOOL_INFO } from '@/types/game';
import { useMobile } from '@/hooks/useMobile';
import { MobileToolbar } from '@/components/mobile/MobileToolbar';
import { MobileTopBar } from '@/components/mobile/MobileTopBar';
import { msg, useMessages, useGT } from 'gt-next';

// Import shadcn components
import { TooltipProvider } from '@/components/ui/tooltip';
import { useCheatCodes } from '@/hooks/useCheatCodes';
import { VinnieDialog } from '@/components/VinnieDialog';
import { CommandMenu } from '@/components/ui/CommandMenu';
import { TipToast } from '@/components/ui/TipToast';
import { useTipSystem } from '@/hooks/useTipSystem';
import { useMultiplayerSync } from '@/hooks/useMultiplayerSync';
import { useCopyRoomLink } from '@/hooks/useCopyRoomLink';
import { useMultiplayerOptional } from '@/context/MultiplayerContext';
import { ShareModal } from '@/components/multiplayer/ShareModal';
import { Copy, Check } from 'lucide-react';

// Import game components
import { OverlayMode } from '@/components/game/types';
import { getOverlayForTool } from '@/components/game/overlays';
import { OverlayModeToggle } from '@/components/game/OverlayModeToggle';
import { Sidebar } from '@/components/game/Sidebar';
import {
  BudgetPanel,
  StatisticsPanel,
  SettingsPanel,
  AdvisorsPanel,
} from '@/components/game/panels';
import { MiniMap } from '@/components/game/MiniMap';
import { TopBar, StatsPanel } from '@/components/game/TopBar';
import { CanvasIsometricGrid } from '@/components/game/CanvasIsometricGrid';
import { useMobileUiSettings } from '@/lib/mobileUiSettings';
import { ensureNativeBridge, onNativeBridgeMessage, postToNative, useNativeHostConfig } from '@/lib/nativeBridge';

// Cargo type names for notifications
const CARGO_TYPE_NAMES = [msg('containers'), msg('bulk materials'), msg('oil')];

const OVERLAY_MODES: OverlayMode[] = ['none', 'power', 'water', 'fire', 'police', 'health', 'education', 'subway'];

type PanelType = 'budget' | 'statistics' | 'advisors';

const BUDGET_KEYS: readonly (keyof Budget)[] = [
  'police',
  'fire',
  'health',
  'education',
  'transportation',
  'parks',
  'power',
  'water',
];

const BUDGET_KEY_SET = new Set<string>(BUDGET_KEYS as readonly string[]);

function isBudgetKey(value: unknown): value is keyof Budget {
  return typeof value === 'string' && BUDGET_KEY_SET.has(value);
}

function buildBudgetPanelData(state: GameState) {
  const categories = BUDGET_KEYS.map((key) => {
    const entry = state.budget[key];
    return {
      key,
      name: entry.name,
      funding: entry.funding,
      cost: entry.cost,
    };
  });

  return {
    stats: {
      population: state.stats.population,
      jobs: state.stats.jobs,
      money: state.stats.money,
      income: state.stats.income,
      expenses: state.stats.expenses,
    },
    categories,
  };
}

function buildStatisticsPanelData(state: GameState) {
  return {
    stats: {
      population: state.stats.population,
      jobs: state.stats.jobs,
      money: state.stats.money,
      income: state.stats.income,
      expenses: state.stats.expenses,
      happiness: state.stats.happiness,
    },
    history: state.history,
  };
}

function buildAdvisorsPanelData(state: GameState) {
  return {
    stats: {
      happiness: state.stats.happiness,
      health: state.stats.health,
      education: state.stats.education,
      safety: state.stats.safety,
      environment: state.stats.environment,
    },
    advisorMessages: state.advisorMessages,
  };
}

function buildPanelData(panel: PanelType, state: GameState) {
  switch (panel) {
    case 'budget':
      return buildBudgetPanelData(state);
    case 'statistics':
      return buildStatisticsPanelData(state);
    case 'advisors':
      return buildAdvisorsPanelData(state);
    default:
      return null;
  }
}

function sendPanelData(panel: PanelType, ref: React.RefObject<GameState>) {
  const nextState = ref.current;
  if (!nextState) {
    return;
  }
  const data = buildPanelData(panel, nextState);
  if (!data) {
    return;
  }

  postToNative({
    type: 'panel.data',
    payload: { panel, data },
  });
}

function isOverlayMode(value: unknown): value is OverlayMode {
  return typeof value === 'string' && OVERLAY_MODES.includes(value as OverlayMode);
}

function isTool(value: unknown): value is Tool {
  return typeof value === 'string' && value in TOOL_INFO;
}

export default function Game({ onExit }: { onExit?: () => void }) {
  const gt = useGT();
  const m = useMessages();
  const { state, latestStateRef, setTool, setActivePanel, addMoney, addNotification, setSpeed, setBudgetFunding } = useGame();
  const [overlayMode, setOverlayMode] = useState<OverlayMode>('none');
  const [selectedTile, setSelectedTile] = useState<{ x: number; y: number } | null>(null);
  const [navigationTarget, setNavigationTarget] = useState<{ x: number; y: number } | null>(null);
  const [viewport, setViewport] = useState<{ offset: { x: number; y: number }; zoom: number; canvasSize: { width: number; height: number } } | null>(null);
  const isInitialMount = useRef(true);
  const { isMobileDevice, isSmallScreen } = useMobile();
  const nativeHostConfig = useNativeHostConfig();
  const isNativeIOSHost = nativeHostConfig.host === 'ios';
  const isMobile = isMobileDevice || isSmallScreen;
  const { settings: mobileUiSettings } = useMobileUiSettings();
  const [showShareModal, setShowShareModal] = useState(false);
  const multiplayer = useMultiplayerOptional();
  
  // Cheat code system
  const {
    triggeredCheat,
    showVinnieDialog,
    setShowVinnieDialog,
    clearTriggeredCheat,
  } = useCheatCodes();
  
  // Tip system for helping new players
  const {
    currentTip,
    isVisible: isTipVisible,
    onContinue: onTipContinue,
    onSkipAll: onTipSkipAll,
  } = useTipSystem(state);
  
  // Multiplayer sync
  const {
    isMultiplayer,
    isHost,
    playerCount,
    roomCode,
    players,
    broadcastPlace,
    leaveRoom,
  } = useMultiplayerSync();
  
  const { copied: copiedRoomLink, handleCopyRoomLink } = useCopyRoomLink(roomCode, 'coop');
  const initialSelectedToolRef = useRef<Tool | null>(null);
  const previousSelectedToolRef = useRef<Tool | null>(null);
  const hasCapturedInitialTool = useRef(false);
  const currentSelectedToolRef = useRef<Tool>(state.selectedTool);
  
  // Keep currentSelectedToolRef in sync with state
  useEffect(() => {
    currentSelectedToolRef.current = state.selectedTool;
  }, [state.selectedTool]);
  
  // Track the initial selectedTool after localStorage loads (with a small delay to allow state to load)
  useEffect(() => {
    if (!hasCapturedInitialTool.current) {
      // Use a timeout to ensure localStorage state has loaded
      const timeoutId = setTimeout(() => {
        initialSelectedToolRef.current = currentSelectedToolRef.current;
        previousSelectedToolRef.current = currentSelectedToolRef.current;
        hasCapturedInitialTool.current = true;
      }, 100);
      return () => clearTimeout(timeoutId);
    }
  }, []); // Only run once on mount
  
  // Auto-set overlay when selecting utility tools (but not on initial page load)
  useEffect(() => {
    if (isInitialMount.current) {
      isInitialMount.current = false;
      return;
    }
    
    // Select tool always resets overlay to none (user is explicitly switching to select)
    if (state.selectedTool === 'select') {
      setTimeout(() => {
        setOverlayMode('none');
      }, 0);
      previousSelectedToolRef.current = state.selectedTool;
      return;
    }
    
    // Subway tool sets overlay when actively selected (not on page load)
    if (state.selectedTool === 'subway' || state.selectedTool === 'subway_station') {
      setTimeout(() => {
        setOverlayMode('subway');
      }, 0);
      previousSelectedToolRef.current = state.selectedTool;
      return;
    }
    
    // Don't auto-set overlay until we've captured the initial tool
    if (!hasCapturedInitialTool.current) {
      return;
    }
    
    // Don't auto-set overlay if this matches the initial tool from localStorage
    if (initialSelectedToolRef.current !== null && 
        initialSelectedToolRef.current === state.selectedTool) {
      return;
    }
    
    // Don't auto-set overlay if tool hasn't changed
    if (previousSelectedToolRef.current === state.selectedTool) {
      return;
    }
    
    // Update previous tool reference
    previousSelectedToolRef.current = state.selectedTool;
    
    setTimeout(() => {
      setOverlayMode(getOverlayForTool(state.selectedTool));
    }, 0);
  }, [state.selectedTool]);

  // Install JS<->Swift bridge and send a ready signal for native hosts.
  useEffect(() => {
    ensureNativeBridge();
    postToNative({
      type: 'host.ready',
      payload: {
        app: 'isocity',
        version: 1,
      },
    });

    postToNative({
      type: 'host.scene',
      payload: {
        screen: 'game',
        inGame: true,
        hudVisible: true,
      },
    });

    return () => {
      postToNative({
        type: 'host.scene',
        payload: {
          screen: 'menu',
          inGame: false,
          hudVisible: false,
        },
      });
    };
  }, []);

  // Emit compact state snapshots so native HUD can render parity UI.
  useEffect(() => {
    postToNative({
      type: 'host.state',
      payload: {
        cityName: state.cityName,
        year: state.year,
        month: state.month,
        day: state.day,
        tick: state.tick,
        speed: state.speed,
        selectedTool: state.selectedTool,
        activePanel: state.activePanel,
        stats: {
          population: state.stats.population,
          money: state.stats.money,
          income: state.stats.income,
          expenses: state.stats.expenses,
          happiness: state.stats.happiness,
          health: state.stats.health,
          education: state.stats.education,
          safety: state.stats.safety,
          environment: state.stats.environment,
          jobs: state.stats.jobs,
          demand: state.stats.demand,
        },
        selectedTile,
        overlayMode,
        mobileUi: mobileUiSettings,
        host: nativeHostConfig,
      },
    });
  }, [
    state.cityName,
    state.year,
    state.month,
    state.day,
    state.tick,
    state.speed,
    state.selectedTool,
    state.activePanel,
    state.stats.population,
    state.stats.money,
    state.stats.income,
    state.stats.expenses,
    state.stats.happiness,
    state.stats.health,
    state.stats.education,
    state.stats.safety,
    state.stats.environment,
    state.stats.jobs,
    state.stats.demand,
    selectedTile,
    overlayMode,
    mobileUiSettings,
    nativeHostConfig,
  ]);

  useEffect(() => {
    postToNative({
      type: 'event.toolChanged',
      payload: { tool: state.selectedTool },
    });
  }, [state.selectedTool]);

  useEffect(() => {
    postToNative({
      type: 'event.selectionChanged',
      payload: selectedTile ? { x: selectedTile.x, y: selectedTile.y } : null,
    });
  }, [selectedTile]);

  // Consume native commands so SwiftUI controls can manipulate the game.
  useEffect(() => {
    return onNativeBridgeMessage((message) => {
      const payload = (message.payload && typeof message.payload === 'object')
        ? (message.payload as Record<string, unknown>)
        : null;

      switch (message.type) {
        case 'tool.set': {
          const tool = payload?.tool;
          if (isTool(tool)) {
            setTool(tool);
          }
          break;
        }
        case 'speed.set': {
          const speed = payload?.speed;
          if (speed === 0 || speed === 1 || speed === 2 || speed === 3) {
            setSpeed(speed);
          }
          break;
        }
        case 'panel.set': {
          const panel = payload?.panel;
          if (panel === 'none' || panel === 'budget' || panel === 'statistics' || panel === 'advisors' || panel === 'settings') {
            setActivePanel(panel);
          }
          break;
        }
        case 'panel.data.request': {
          const panel = payload?.panel;
          if (panel === 'budget' || panel === 'statistics' || panel === 'advisors') {
            sendPanelData(panel, latestStateRef);
          }
          break;
        }
        case 'budget.setFunding': {
          const key = payload?.key;
          const funding = payload?.funding;
          if (isBudgetKey(key) && typeof funding === 'number') {
            setBudgetFunding(key, funding);
            sendPanelData('budget', latestStateRef);
          }
          break;
        }
        case 'overlay.set': {
          const mode = payload?.mode;
          if (isOverlayMode(mode)) {
            setOverlayMode(mode);
          }
          break;
        }
        case 'selection.set': {
          const x = payload?.x;
          const y = payload?.y;
          if (typeof x === 'number' && typeof y === 'number') {
            const gridX = Math.round(x);
            const gridY = Math.round(y);
            if (gridX >= 0 && gridY >= 0 && gridX < state.gridSize && gridY < state.gridSize) {
              setSelectedTile({ x: gridX, y: gridY });
            }
          }
          break;
        }
        case 'selection.clear':
          setSelectedTile(null);
          break;
        default:
          break;
      }
    });
  }, [latestStateRef, setBudgetFunding, setTool, setSpeed, setActivePanel, setOverlayMode, state.gridSize]);
  
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      // Don't trigger shortcuts when typing in input fields
      const target = e.target as HTMLElement;
      if (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA' || target.isContentEditable) {
        return;
      }

      if (e.key === 'Escape') {
        if (overlayMode !== 'none') {
          setOverlayMode('none');
        } else if (state.activePanel !== 'none') {
          setActivePanel('none');
        } else if (selectedTile) {
          setSelectedTile(null);
        } else if (state.selectedTool !== 'select') {
          setTool('select');
        }
      } else if (e.key === 'b' || e.key === 'B') {
        e.preventDefault();
        setTool('bulldoze');
      } else if (e.key === 'p' || e.key === 'P') {
        e.preventDefault();
        // Toggle pause/unpause: if paused (speed 0), resume to normal (speed 1)
        // If running, pause (speed 0)
        setSpeed(state.speed === 0 ? 1 : 0);
      }
    };
    
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [state.activePanel, state.selectedTool, state.speed, selectedTile, setActivePanel, setTool, setSpeed, overlayMode]);

  // Handle cheat code triggers
  useEffect(() => {
    if (!triggeredCheat) return;

    switch (triggeredCheat.type) {
      case 'konami':
        addMoney(triggeredCheat.amount);
        addNotification(
          gt('Retro Cheat Activated!'),
          gt('Your accountants are confused but not complaining. You received $50,000!'),
          'trophy'
        );
        clearTriggeredCheat();
        break;

      case 'motherlode':
        addMoney(triggeredCheat.amount);
        addNotification(
          gt('Motherlode!'),
          gt('Your treasury just got a lot heavier. You received $1,000,000!'),
          'trophy'
        );
        clearTriggeredCheat();
        break;

      case 'vinnie':
        // Vinnie dialog is handled by VinnieDialog component
        clearTriggeredCheat();
        break;
    }
  }, [triggeredCheat, addMoney, addNotification, clearTriggeredCheat]);
  
  // Track barge deliveries to show occasional notifications
  const bargeDeliveryCountRef = useRef(0);
  const showWebMobileChrome = !isNativeIOSHost;
  const mobileTopInset = showWebMobileChrome ? (mobileUiSettings.hudDensity === 'minimal' ? 58 : mobileUiSettings.hudDensity === 'full' ? 112 : 72) : 0;
  const mobileBottomInset = showWebMobileChrome ? (mobileUiSettings.toolLayout === 'quick' ? 84 : 74) : 0;
  
  // Handle barge cargo delivery - adds money to the city treasury
  const handleBargeDelivery = useCallback((cargoValue: number, cargoType: number) => {
    addMoney(cargoValue);
    bargeDeliveryCountRef.current++;

    // Show a notification every 5 deliveries to avoid spam
    if (bargeDeliveryCountRef.current % 5 === 1) {
      const cargoName = CARGO_TYPE_NAMES[cargoType] || msg('cargo');
      addNotification(
        gt('Cargo Delivered'),
        gt('A shipment of {cargoName} has arrived at the marina. +${cargoValue} trade revenue.', { cargoName: m(cargoName), cargoValue }),
        'ship'
      );
    }
  }, [addMoney, addNotification, gt, m]);

  // Mobile layout
  if (isMobile) {
    return (
      <TooltipProvider>
        <div className="w-full h-full overflow-hidden bg-background flex flex-col">
          {/* Mobile Top Bar */}
          {showWebMobileChrome && (
            <MobileTopBar 
              selectedTile={selectedTile && state.selectedTool === 'select' ? state.grid[selectedTile.y][selectedTile.x] : null}
              services={state.services}
              onCloseTile={() => setSelectedTile(null)}
              onShare={() => setShowShareModal(true)}
              onExit={onExit}
              hudDensity={mobileUiSettings.hudDensity}
            />
          )}
          
          {/* Share Modal for mobile co-op */}
          {multiplayer && (
            <ShareModal
              open={showShareModal}
              onOpenChange={setShowShareModal}
            />
          )}
          
          {/* Main canvas area - fills remaining space, with padding for top/bottom bars */}
          <div className="flex-1 relative overflow-hidden" style={{ paddingTop: `${mobileTopInset}px`, paddingBottom: `${mobileBottomInset}px` }}>
            <CanvasIsometricGrid 
              overlayMode={overlayMode} 
              selectedTile={selectedTile} 
              setSelectedTile={setSelectedTile}
              isMobile={true}
              navigationTarget={navigationTarget}
              onNavigationComplete={() => setNavigationTarget(null)}
              onViewportChange={setViewport}
              onBargeDelivery={handleBargeDelivery}
            />

            {showWebMobileChrome && mobileUiSettings.showMinimap && (
              <MiniMap
                compact
                onNavigate={(x, y) => setNavigationTarget({ x, y })}
                viewport={viewport}
              />
            )}
            
            {/* Multiplayer Players Indicator - Mobile */}
            {isMultiplayer && (
              <div className="absolute top-2 right-2 z-20">
                <div className="bg-slate-900/90 border border-slate-700 rounded-lg px-2 py-1.5 shadow-lg">
                  <div className="flex items-center gap-1.5 text-xs text-white">
                    {roomCode && (
                      <>
                        <span className="font-mono tracking-wider">{roomCode}</span>
                        <button
                          onClick={handleCopyRoomLink}
                          className="p-0.5 hover:bg-white/10 rounded transition-colors"
                          title="Copy invite link"
                        >
                          {copiedRoomLink ? (
                            <Check className="w-3 h-3 text-green-400" />
                          ) : (
                            <Copy className="w-3 h-3 text-slate-400" />
                          )}
                        </button>
                      </>
                    )}
                  </div>
                  {players.length > 0 && (
                    <div className="mt-1 space-y-0.5">
                      {players.map((player) => (
                        <div key={player.id} className="flex items-center gap-1 text-[10px] text-slate-400">
                          <span className="w-1.5 h-1.5 rounded-full bg-green-500" />
                          {player.name}
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              </div>
            )}
          </div>
          
          {/* Mobile Bottom Toolbar */}
          {showWebMobileChrome && (
            <MobileToolbar 
              onOpenPanel={(panel) => setActivePanel(panel)}
              overlayMode={overlayMode}
              setOverlayMode={setOverlayMode}
              toolLayout={mobileUiSettings.toolLayout}
            />
          )}
          
          {/* Panels - render as fullscreen modals on mobile */}
          {showWebMobileChrome && state.activePanel === 'budget' && <BudgetPanel />}
          {showWebMobileChrome && state.activePanel === 'statistics' && <StatisticsPanel />}
          {showWebMobileChrome && state.activePanel === 'advisors' && <AdvisorsPanel />}
          {showWebMobileChrome && state.activePanel === 'settings' && <SettingsPanel />}
          
          <VinnieDialog open={showVinnieDialog} onOpenChange={setShowVinnieDialog} />
          
          {/* Tip Toast for helping new players */}
          {showWebMobileChrome && (
            <TipToast
              message={currentTip || ''}
              isVisible={isTipVisible}
              onContinue={onTipContinue}
              onSkipAll={onTipSkipAll}
            />
          )}
        </div>
      </TooltipProvider>
    );
  }

  // Desktop layout
  return (
    <TooltipProvider>
      <div className="w-full h-full min-h-[720px] overflow-hidden bg-background flex">
        <Sidebar onExit={onExit} />
        
        <div className="flex-1 flex flex-col ml-56">
          <TopBar />
          <StatsPanel />
          <div className="flex-1 relative overflow-visible">
            <CanvasIsometricGrid 
              overlayMode={overlayMode} 
              selectedTile={selectedTile} 
              setSelectedTile={setSelectedTile}
              navigationTarget={navigationTarget}
              onNavigationComplete={() => setNavigationTarget(null)}
              onViewportChange={setViewport}
              onBargeDelivery={handleBargeDelivery}
            />
            <OverlayModeToggle overlayMode={overlayMode} setOverlayMode={setOverlayMode} />
            <MiniMap onNavigate={(x, y) => setNavigationTarget({ x, y })} viewport={viewport} />
            
            {/* Multiplayer Players Indicator */}
            {isMultiplayer && (
              <div className="absolute top-4 right-4 z-20">
                <div className="bg-slate-900/90 border border-slate-700 rounded-lg px-3 py-2 shadow-lg min-w-[120px]">
                  <div className="flex items-center gap-2 text-sm text-white">
                    {roomCode && (
                      <>
                        <span className="font-mono font-medium tracking-wider">{roomCode}</span>
                        <button
                          onClick={handleCopyRoomLink}
                          className="p-1 hover:bg-white/10 rounded transition-colors"
                          title="Copy invite link"
                        >
                          {copiedRoomLink ? (
                            <Check className="w-3.5 h-3.5 text-green-400" />
                          ) : (
                            <Copy className="w-3.5 h-3.5 text-slate-400 hover:text-white" />
                          )}
                        </button>
                      </>
                    )}
                  </div>
                  {players.length > 0 && (
                    <div className="mt-1.5 space-y-0.5">
                      {players.map((player) => (
                        <div key={player.id} className="flex items-center gap-1.5 text-xs text-slate-400">
                          <span className="w-2 h-2 rounded-full bg-green-500" />
                          {player.name}
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              </div>
            )}
          </div>
        </div>
        
        {state.activePanel === 'budget' && <BudgetPanel />}
        {state.activePanel === 'statistics' && <StatisticsPanel />}
        {state.activePanel === 'advisors' && <AdvisorsPanel />}
        {state.activePanel === 'settings' && <SettingsPanel />}
        
        <VinnieDialog open={showVinnieDialog} onOpenChange={setShowVinnieDialog} />
        <CommandMenu />
        
        {/* Tip Toast for helping new players */}
        <TipToast
          message={currentTip || ''}
          isVisible={isTipVisible}
          onContinue={onTipContinue}
          onSkipAll={onTipSkipAll}
        />
      </div>
    </TooltipProvider>
  );
}
