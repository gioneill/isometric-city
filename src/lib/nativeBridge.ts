'use client';

import { useState } from 'react';

export type BridgePayload = Record<string, unknown> | null;

export interface BridgeMessage {
  type: string;
  payload?: BridgePayload;
}

export type NativeGestureMode = 'web' | 'native';

export interface NativeHostConfig {
  host: 'web' | 'ios';
  gestureMode: NativeGestureMode;
}

export interface NativeCameraUpdate {
  offsetX?: number;
  offsetY?: number;
  zoom?: number;
  x?: number;
  y?: number;
  scale?: number;
  rotation?: number;
}

export interface NativeCameraSnapshot {
  offsetX: number;
  offsetY: number;
  zoom: number;
}

export interface NativeHitTestResult {
  screenX: number;
  screenY: number;
  gridX: number;
  gridY: number;
  inBounds: boolean;
  buildingType?: string;
  originX?: number;
  originY?: number;
}

export interface NativeCanvasApi {
  setCamera: (camera: NativeCameraUpdate) => void;
  getCamera: () => NativeCameraSnapshot;
  hitTest: (screenX: number, screenY: number) => NativeHitTestResult;
}

const BRIDGE_EVENT = 'isocity-native-bridge-dispatch';

function safeNumber(value: unknown): number | undefined {
  return typeof value === 'number' && Number.isFinite(value) ? value : undefined;
}

function parseHostConfig(search: string): NativeHostConfig {
  const params = new URLSearchParams(search);
  const host = params.get('host') === 'ios' ? 'ios' : 'web';
  const gestureMode: NativeGestureMode = params.get('gesture') === 'native' ? 'native' : 'web';
  return { host, gestureMode };
}

export function readNativeHostConfig(): NativeHostConfig {
  if (typeof window === 'undefined') {
    return { host: 'web', gestureMode: 'web' };
  }
  return parseHostConfig(window.location.search);
}

export function useNativeHostConfig(): NativeHostConfig {
  const [config] = useState<NativeHostConfig>(() => readNativeHostConfig());
  return config;
}

export function ensureNativeBridge() {
  if (typeof window === 'undefined') {
    return;
  }

  if (!window.bridge || typeof window.bridge.dispatch !== 'function') {
    window.bridge = {
      dispatch: (message: BridgeMessage) => {
        window.dispatchEvent(new CustomEvent<BridgeMessage>(BRIDGE_EVENT, { detail: message }));
      },
    };
  }
}

export function postToNative(message: BridgeMessage) {
  if (typeof window === 'undefined') {
    return;
  }

  ensureNativeBridge();

  const payload: BridgeMessage = {
    type: message.type,
    payload: message.payload ?? null,
  };

  try {
    window.webkit?.messageHandlers?.bridge?.postMessage(payload);
  } catch {
    // Ignore postMessage failures when not running inside a native host.
  }
}

export function onNativeBridgeMessage(handler: (message: BridgeMessage) => void): () => void {
  if (typeof window === 'undefined') {
    return () => {};
  }

  ensureNativeBridge();

  const listener = (event: Event) => {
    const customEvent = event as CustomEvent<BridgeMessage>;
    const message = customEvent.detail;
    if (!message?.type) {
      return;
    }
    handler(message);
  };

  window.addEventListener(BRIDGE_EVENT, listener);
  return () => window.removeEventListener(BRIDGE_EVENT, listener);
}

export function buildCameraUpdate(payload: BridgePayload): NativeCameraUpdate | null {
  if (!payload || typeof payload !== 'object') {
    return null;
  }

  const camera = payload as Record<string, unknown>;
  const update: NativeCameraUpdate = {
    offsetX: safeNumber(camera.offsetX),
    offsetY: safeNumber(camera.offsetY),
    zoom: safeNumber(camera.zoom),
    x: safeNumber(camera.x),
    y: safeNumber(camera.y),
    scale: safeNumber(camera.scale),
    rotation: safeNumber(camera.rotation),
  };

  if (
    update.offsetX === undefined &&
    update.offsetY === undefined &&
    update.zoom === undefined &&
    update.x === undefined &&
    update.y === undefined &&
    update.scale === undefined &&
    update.rotation === undefined
  ) {
    return null;
  }

  return update;
}

declare global {
  interface Window {
    bridge?: {
      dispatch: (message: BridgeMessage) => void;
    };
    __native?: Partial<NativeCanvasApi>;
    webkit?: {
      messageHandlers?: {
        bridge?: {
          postMessage: (message: BridgeMessage) => void;
        };
      };
    };
  }
}
