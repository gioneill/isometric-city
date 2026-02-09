'use client';

import { useCallback, useEffect, useState } from 'react';

export type MobileHudDensity = 'minimal' | 'compact' | 'full';
export type MobileToolLayout = 'category' | 'quick';

export interface MobileUiSettings {
  hudDensity: MobileHudDensity;
  toolLayout: MobileToolLayout;
  showMinimap: boolean;
}

const STORAGE_KEY = 'isocity-mobile-ui-settings';
const SETTINGS_EVENT = 'isocity-mobile-ui-settings-updated';

const DEFAULT_SETTINGS: MobileUiSettings = {
  hudDensity: 'compact',
  toolLayout: 'category',
  showMinimap: false,
};

function normalizeSettings(raw: unknown): MobileUiSettings {
  if (!raw || typeof raw !== 'object') {
    return DEFAULT_SETTINGS;
  }

  const candidate = raw as Partial<MobileUiSettings>;
  const hudDensity: MobileHudDensity =
    candidate.hudDensity === 'minimal' || candidate.hudDensity === 'compact' || candidate.hudDensity === 'full'
      ? candidate.hudDensity
      : DEFAULT_SETTINGS.hudDensity;

  const toolLayout: MobileToolLayout =
    candidate.toolLayout === 'category' || candidate.toolLayout === 'quick'
      ? candidate.toolLayout
      : DEFAULT_SETTINGS.toolLayout;

  return {
    hudDensity,
    toolLayout,
    showMinimap: Boolean(candidate.showMinimap),
  };
}

export function readMobileUiSettings(): MobileUiSettings {
  if (typeof window === 'undefined') {
    return DEFAULT_SETTINGS;
  }

  try {
    const saved = window.localStorage.getItem(STORAGE_KEY);
    if (!saved) {
      return DEFAULT_SETTINGS;
    }
    return normalizeSettings(JSON.parse(saved));
  } catch {
    return DEFAULT_SETTINGS;
  }
}

export function writeMobileUiSettings(partial: Partial<MobileUiSettings>): MobileUiSettings {
  if (typeof window === 'undefined') {
    return normalizeSettings({ ...DEFAULT_SETTINGS, ...partial });
  }

  const next = normalizeSettings({ ...readMobileUiSettings(), ...partial });
  window.localStorage.setItem(STORAGE_KEY, JSON.stringify(next));
  window.dispatchEvent(new CustomEvent<MobileUiSettings>(SETTINGS_EVENT, { detail: next }));
  return next;
}

export function subscribeMobileUiSettings(listener: (settings: MobileUiSettings) => void): () => void {
  if (typeof window === 'undefined') {
    return () => {};
  }

  const handleCustomEvent = (event: Event) => {
    const customEvent = event as CustomEvent<MobileUiSettings>;
    listener(normalizeSettings(customEvent.detail));
  };

  const handleStorageEvent = (event: StorageEvent) => {
    if (event.key === STORAGE_KEY) {
      listener(readMobileUiSettings());
    }
  };

  window.addEventListener(SETTINGS_EVENT, handleCustomEvent);
  window.addEventListener('storage', handleStorageEvent);

  return () => {
    window.removeEventListener(SETTINGS_EVENT, handleCustomEvent);
    window.removeEventListener('storage', handleStorageEvent);
  };
}

export function useMobileUiSettings() {
  const [settings, setSettings] = useState<MobileUiSettings>(() => readMobileUiSettings());

  useEffect(() => {
    return subscribeMobileUiSettings(setSettings);
  }, []);

  const updateSettings = useCallback((partial: Partial<MobileUiSettings>) => {
    setSettings(writeMobileUiSettings(partial));
  }, []);

  return { settings, updateSettings };
}
