'use client';

import React, { useState, useRef } from 'react';
import { GameProvider } from '@/context/GameContext';
import { MultiplayerContextProvider } from '@/context/MultiplayerContext';
import Game from '@/components/Game';
import { CoopModal } from '@/components/multiplayer/CoopModal';
import { GameState } from '@/types/game';
import { compressToUTF16 } from 'lz-string';
import { useRouter } from 'next/navigation';

const STORAGE_KEY = 'isocity-game-state';
const SAVED_CITIES_INDEX_KEY = 'isocity-saved-cities-index';

function saveCityToIndex(state: GameState, roomCode?: string): void {
  if (typeof window === 'undefined') return;
  try {
    const saved = localStorage.getItem(SAVED_CITIES_INDEX_KEY);
    const cities = saved ? JSON.parse(saved) : [];

    const cityMeta = {
      id: state.id || `city-${Date.now()}`,
      cityName: state.cityName || 'Co-op City',
      population: state.stats.population,
      money: state.stats.money,
      year: state.year,
      month: state.month,
      gridSize: state.gridSize,
      savedAt: Date.now(),
      roomCode: roomCode,
    };

    const existingIndex = cities.findIndex((c: { id: string; roomCode?: string }) =>
      c.id === cityMeta.id || (roomCode && c.roomCode === roomCode)
    );

    if (existingIndex >= 0) {
      cities[existingIndex] = cityMeta;
    } else {
      cities.unshift(cityMeta);
    }

    localStorage.setItem(SAVED_CITIES_INDEX_KEY, JSON.stringify(cities.slice(0, 20)));
  } catch (e) {
    console.error('Failed to save city to index:', e);
  }
}

export default function CoopClientPage({ roomCode }: { roomCode: string }) {
  const router = useRouter();
  const normalizedRoomCode = roomCode.toUpperCase();

  const [showGame, setShowGame] = useState(false);
  const [showCoopModal, setShowCoopModal] = useState(true);
  const [startFreshGame, setStartFreshGame] = useState(false);

  const isStartingGameRef = useRef(false);

  const handleExitGame = () => {
    router.push('/');
  };

  const handleCoopStart = (isHost: boolean, initialState?: GameState, code?: string) => {
    isStartingGameRef.current = true;

    if (isHost && initialState) {
      try {
        const compressed = compressToUTF16(JSON.stringify(initialState));
        localStorage.setItem(STORAGE_KEY, compressed);
        if (code) {
          saveCityToIndex(initialState, code);
        }
      } catch (e) {
        console.error('Failed to save co-op state:', e);
      }
      setStartFreshGame(false);
    } else if (!isHost && initialState) {
      try {
        const compressed = compressToUTF16(JSON.stringify(initialState));
        localStorage.setItem(STORAGE_KEY, compressed);
        if (code) {
          saveCityToIndex(initialState, code);
        }
      } catch (e) {
        console.error('Failed to save co-op state:', e);
      }
      setStartFreshGame(false);
    } else {
      setStartFreshGame(true);
    }

    setShowGame(true);
    setShowCoopModal(false);
  };

  const handleModalClose = (open: boolean) => {
    if (!open && !showGame && !isStartingGameRef.current) {
      router.push('/');
    }
    setShowCoopModal(open);
  };

  return (
    <MultiplayerContextProvider>
      {showGame ? (
        <GameProvider startFresh={startFreshGame}>
          <main className="h-screen w-screen overflow-hidden">
            <Game onExit={handleExitGame} />
          </main>
        </GameProvider>
      ) : (
        <main className="min-h-screen bg-gradient-to-br from-slate-950 via-slate-900 to-slate-950 flex items-center justify-center">
          <CoopModal
            open={showCoopModal}
            onOpenChange={handleModalClose}
            onStartGame={handleCoopStart}
            pendingRoomCode={normalizedRoomCode}
          />
        </main>
      )}
    </MultiplayerContextProvider>
  );
}

