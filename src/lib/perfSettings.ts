import { useEffect, useState } from 'react';

const PERF_MODE_KEY = 'isocity-perf-mode';
const PERF_MODE_EVENT = 'isocity-perf-mode-change';

export function readPerfMode(): boolean {
  if (typeof window === 'undefined') return true;
  const stored = localStorage.getItem(PERF_MODE_KEY);
  if (stored === null) return true;
  return stored === 'true';
}

export function setPerfMode(enabled: boolean): void {
  if (typeof window === 'undefined') return;
  localStorage.setItem(PERF_MODE_KEY, String(enabled));
  window.dispatchEvent(new CustomEvent<boolean>(PERF_MODE_EVENT, { detail: enabled }));
}

export function usePerfMode(): [boolean, (enabled: boolean) => void] {
  const [enabled, setEnabled] = useState(readPerfMode);

  useEffect(() => {
    const handleCustomEvent = (event: Event) => {
      const detail = (event as CustomEvent<boolean>).detail;
      if (typeof detail === 'boolean') {
        setEnabled(detail);
        return;
      }
      setEnabled(readPerfMode());
    };

    const handleStorage = (event: StorageEvent) => {
      if (event.key === PERF_MODE_KEY) {
        setEnabled(readPerfMode());
      }
    };

    window.addEventListener(PERF_MODE_EVENT, handleCustomEvent as EventListener);
    window.addEventListener('storage', handleStorage);
    return () => {
      window.removeEventListener(PERF_MODE_EVENT, handleCustomEvent as EventListener);
      window.removeEventListener('storage', handleStorage);
    };
  }, []);

  const update = (nextValue: boolean) => {
    setPerfMode(nextValue);
    setEnabled(nextValue);
  };

  return [enabled, update];
}
