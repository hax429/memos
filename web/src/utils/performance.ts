/**
 * Performance utility functions for optimization
 */

/**
 * Debounce function - delays execution until after wait time has elapsed since last call
 * @param func - Function to debounce
 * @param wait - Wait time in milliseconds
 * @returns Debounced function
 */
export function debounce<T extends (...args: any[]) => any>(func: T, wait: number): T {
  let timeoutId: ReturnType<typeof setTimeout> | null = null;

  return ((...args: Parameters<T>) => {
    if (timeoutId) {
      clearTimeout(timeoutId);
    }

    timeoutId = setTimeout(() => {
      func(...args);
    }, wait);
  }) as T;
}

/**
 * Throttle function - ensures function is called at most once per wait period
 * @param func - Function to throttle
 * @param wait - Wait time in milliseconds
 * @returns Throttled function
 */
export function throttle<T extends (...args: any[]) => any>(func: T, wait: number): T {
  let inThrottle = false;
  let lastArgs: Parameters<T> | null = null;

  return ((...args: Parameters<T>) => {
    if (!inThrottle) {
      func(...args);
      inThrottle = true;

      setTimeout(() => {
        inThrottle = false;
        if (lastArgs) {
          func(...lastArgs);
          lastArgs = null;
        }
      }, wait);
    } else {
      lastArgs = args;
    }
  }) as T;
}

/**
 * RequestAnimationFrame-based throttle for scroll/resize handlers
 * @param func - Function to throttle
 * @returns RAF-throttled function
 */
export function rafThrottle<T extends (...args: any[]) => any>(func: T): T {
  let rafId: number | null = null;

  return ((...args: Parameters<T>) => {
    if (rafId) {
      return;
    }

    rafId = requestAnimationFrame(() => {
      func(...args);
      rafId = null;
    });
  }) as T;
}

/**
 * Measure function execution time
 * @param name - Name for the measurement
 * @param func - Function to measure
 * @returns Result of the function
 */
export async function measurePerformance<T>(name: string, func: () => T | Promise<T>): Promise<T> {
  const startMark = `${name}-start`;
  const endMark = `${name}-end`;
  const measureName = name;

  try {
    performance.mark(startMark);
    const result = await func();
    performance.mark(endMark);
    performance.measure(measureName, startMark, endMark);

    const measure = performance.getEntriesByName(measureName)[0];
    console.debug(`Performance [${name}]: ${measure.duration.toFixed(2)}ms`);

    return result;
  } finally {
    // Clean up marks
    performance.clearMarks(startMark);
    performance.clearMarks(endMark);
    performance.clearMeasures(measureName);
  }
}

/**
 * Lazy load images with intersection observer
 * @param img - Image element
 * @param src - Source URL
 */
export function lazyLoadImage(img: HTMLImageElement, src: string): void {
  if ("IntersectionObserver" in window) {
    const observer = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          img.src = src;
          observer.unobserve(img);
        }
      });
    });

    observer.observe(img);
  } else {
    // Fallback for browsers without IntersectionObserver
    img.src = src;
  }
}

/**
 * Prefetch resource
 * @param url - URL to prefetch
 * @param type - Resource type (script, style, image, etc.)
 */
export function prefetchResource(url: string, type: "script" | "style" | "image" | "fetch" = "fetch"): void {
  const link = document.createElement("link");
  link.rel = "prefetch";
  link.as = type;
  link.href = url;
  document.head.appendChild(link);
}

/**
 * Preload critical resource
 * @param url - URL to preload
 * @param type - Resource type
 */
export function preloadResource(url: string, type: "script" | "style" | "image" | "fetch" = "fetch"): void {
  const link = document.createElement("link");
  link.rel = "preload";
  link.as = type;
  link.href = url;
  document.head.appendChild(link);
}

/**
 * Check if user prefers reduced motion
 */
export function prefersReducedMotion(): boolean {
  return window.matchMedia("(prefers-reduced-motion: reduce)").matches;
}

/**
 * Get safe animation duration based on user preference
 * @param duration - Default duration in milliseconds
 * @returns Duration (0 if user prefers reduced motion)
 */
export function getSafeAnimationDuration(duration: number): number {
  return prefersReducedMotion() ? 0 : duration;
}

/**
 * Batch DOM reads and writes to prevent layout thrashing
 */
export class DOMBatcher {
  private readQueue: Array<() => void> = [];
  private writeQueue: Array<() => void> = [];
  private rafId: number | null = null;

  read(callback: () => void): void {
    this.readQueue.push(callback);
    this.schedule();
  }

  write(callback: () => void): void {
    this.writeQueue.push(callback);
    this.schedule();
  }

  private schedule(): void {
    if (this.rafId) {
      return;
    }

    this.rafId = requestAnimationFrame(() => {
      // Execute all reads first
      this.readQueue.forEach((callback) => callback());
      this.readQueue = [];

      // Then execute all writes
      this.writeQueue.forEach((callback) => callback());
      this.writeQueue = [];

      this.rafId = null;
    });
  }

  clear(): void {
    if (this.rafId) {
      cancelAnimationFrame(this.rafId);
      this.rafId = null;
    }
    this.readQueue = [];
    this.writeQueue = [];
  }
}

/**
 * Create singleton DOM batcher
 */
export const domBatcher = new DOMBatcher();
