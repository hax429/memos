import { useCallback, useEffect, useRef } from "react";
import { debounce } from "@/utils/performance";

/**
 * Hook to create a debounced function
 * @param callback - Function to debounce
 * @param wait - Wait time in milliseconds
 * @returns Debounced function
 */
export function useDebounce<T extends (...args: any[]) => any>(callback: T, wait: number): T {
  const debouncedFn = useRef<T>();

  useEffect(() => {
    debouncedFn.current = debounce(callback, wait);
  }, [callback, wait]);

  return useCallback(
    ((...args: Parameters<T>) => {
      return debouncedFn.current?.(...args);
    }) as T,
    [],
  );
}

export default useDebounce;
