import { useCallback, useEffect, useRef } from "react";
import { rafThrottle, throttle } from "@/utils/performance";

/**
 * Hook to create a throttled function
 * @param callback - Function to throttle
 * @param wait - Wait time in milliseconds
 * @returns Throttled function
 */
export function useThrottle<T extends (...args: any[]) => any>(callback: T, wait: number): T {
  const throttledFn = useRef<T>();

  useEffect(() => {
    throttledFn.current = throttle(callback, wait);
  }, [callback, wait]);

  return useCallback(
    ((...args: Parameters<T>) => {
      return throttledFn.current?.(...args);
    }) as T,
    [],
  );
}

/**
 * Hook to create a RAF-throttled function (for scroll/resize handlers)
 * @param callback - Function to throttle
 * @returns RAF-throttled function
 */
export function useRafThrottle<T extends (...args: any[]) => any>(callback: T): T {
  const throttledFn = useRef<T>();

  useEffect(() => {
    throttledFn.current = rafThrottle(callback);
  }, [callback]);

  return useCallback(
    ((...args: Parameters<T>) => {
      return throttledFn.current?.(...args);
    }) as T,
    [],
  );
}

export default useThrottle;
