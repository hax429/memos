/**
 * Web Vitals Performance Monitoring
 * Tracks Core Web Vitals: LCP, FID, CLS, FCP, TTFB, INP
 */

type MetricName = "CLS" | "FCP" | "FID" | "LCP" | "TTFB" | "INP";

interface Metric {
  name: MetricName;
  value: number;
  rating: "good" | "needs-improvement" | "poor";
  delta: number;
  id: string;
}

type ReportCallback = (metric: Metric) => void;

/**
 * Get rating based on metric thresholds
 */
function getRating(name: MetricName, value: number): "good" | "needs-improvement" | "poor" {
  const thresholds: Record<MetricName, { good: number; poor: number }> = {
    CLS: { good: 0.1, poor: 0.25 },
    FCP: { good: 1800, poor: 3000 },
    FID: { good: 100, poor: 300 },
    LCP: { good: 2500, poor: 4000 },
    TTFB: { good: 800, poor: 1800 },
    INP: { good: 200, poor: 500 },
  };

  const threshold = thresholds[name];
  if (value <= threshold.good) return "good";
  if (value <= threshold.poor) return "needs-improvement";
  return "poor";
}

/**
 * Report metric to console and custom callback
 */
function reportMetric(metric: Metric, callback?: ReportCallback): void {
  // Log to console in development
  if (import.meta.env.DEV) {
    const emoji = metric.rating === "good" ? "✅" : metric.rating === "needs-improvement" ? "⚠️" : "❌";
    console.log(`${emoji} [Web Vitals] ${metric.name}:`, {
      value: metric.value.toFixed(2),
      rating: metric.rating,
      id: metric.id,
    });
  }

  // Send to analytics or custom callback
  callback?.(metric);

  // You can also send to analytics services here
  // Example: sendToAnalytics(metric);
}

/**
 * Measure Largest Contentful Paint (LCP)
 */
function measureLCP(callback?: ReportCallback): void {
  if (!("PerformanceObserver" in window)) return;

  try {
    const observer = new PerformanceObserver((list) => {
      const entries = list.getEntries();
      const lastEntry = entries[entries.length - 1];

      const metric: Metric = {
        name: "LCP",
        value: lastEntry.startTime,
        rating: getRating("LCP", lastEntry.startTime),
        delta: lastEntry.startTime,
        id: `v3-${Date.now()}-${Math.random()}`,
      };

      reportMetric(metric, callback);
    });

    observer.observe({ type: "largest-contentful-paint", buffered: true });
  } catch (error) {
    console.debug("LCP measurement failed:", error);
  }
}

/**
 * Measure First Input Delay (FID)
 */
function measureFID(callback?: ReportCallback): void {
  if (!("PerformanceObserver" in window)) return;

  try {
    const observer = new PerformanceObserver((list) => {
      const entries = list.getEntries();
      entries.forEach((entry: any) => {
        const metric: Metric = {
          name: "FID",
          value: entry.processingStart - entry.startTime,
          rating: getRating("FID", entry.processingStart - entry.startTime),
          delta: entry.processingStart - entry.startTime,
          id: `v3-${Date.now()}-${Math.random()}`,
        };

        reportMetric(metric, callback);
      });
    });

    observer.observe({ type: "first-input", buffered: true });
  } catch (error) {
    console.debug("FID measurement failed:", error);
  }
}

/**
 * Measure Cumulative Layout Shift (CLS)
 */
function measureCLS(callback?: ReportCallback): void {
  if (!("PerformanceObserver" in window)) return;

  try {
    let clsValue = 0;
    const observer = new PerformanceObserver((list) => {
      for (const entry of list.getEntries() as any[]) {
        if (!entry.hadRecentInput) {
          clsValue += entry.value;
        }
      }

      const metric: Metric = {
        name: "CLS",
        value: clsValue,
        rating: getRating("CLS", clsValue),
        delta: clsValue,
        id: `v3-${Date.now()}-${Math.random()}`,
      };

      reportMetric(metric, callback);
    });

    observer.observe({ type: "layout-shift", buffered: true });
  } catch (error) {
    console.debug("CLS measurement failed:", error);
  }
}

/**
 * Measure First Contentful Paint (FCP)
 */
function measureFCP(callback?: ReportCallback): void {
  if (!("PerformanceObserver" in window)) return;

  try {
    const observer = new PerformanceObserver((list) => {
      const entries = list.getEntries();
      entries.forEach((entry) => {
        const metric: Metric = {
          name: "FCP",
          value: entry.startTime,
          rating: getRating("FCP", entry.startTime),
          delta: entry.startTime,
          id: `v3-${Date.now()}-${Math.random()}`,
        };

        reportMetric(metric, callback);
        observer.disconnect();
      });
    });

    observer.observe({ type: "paint", buffered: true });
  } catch (error) {
    console.debug("FCP measurement failed:", error);
  }
}

/**
 * Measure Time to First Byte (TTFB)
 */
function measureTTFB(callback?: ReportCallback): void {
  try {
    const navigationEntry = performance.getEntriesByType("navigation")[0] as PerformanceNavigationTiming;

    if (navigationEntry) {
      const ttfb = navigationEntry.responseStart - navigationEntry.requestStart;

      const metric: Metric = {
        name: "TTFB",
        value: ttfb,
        rating: getRating("TTFB", ttfb),
        delta: ttfb,
        id: `v3-${Date.now()}-${Math.random()}`,
      };

      reportMetric(metric, callback);
    }
  } catch (error) {
    console.debug("TTFB measurement failed:", error);
  }
}

/**
 * Measure Interaction to Next Paint (INP) - newer metric replacing FID
 */
function measureINP(callback?: ReportCallback): void {
  if (!("PerformanceObserver" in window)) return;

  try {
    let maxDuration = 0;

    const observer = new PerformanceObserver((list) => {
      const entries = list.getEntries();
      entries.forEach((entry: any) => {
        if (entry.duration > maxDuration) {
          maxDuration = entry.duration;

          const metric: Metric = {
            name: "INP",
            value: maxDuration,
            rating: getRating("INP", maxDuration),
            delta: maxDuration,
            id: `v3-${Date.now()}-${Math.random()}`,
          };

          reportMetric(metric, callback);
        }
      });
    });

    // Use event type for interaction tracking
    observer.observe({ type: "event", buffered: true } as PerformanceObserverInit);
  } catch (error) {
    console.debug("INP measurement failed:", error);
  }
}

/**
 * Initialize all Web Vitals measurements
 * @param callback - Optional callback to receive metrics
 */
export function initWebVitals(callback?: ReportCallback): void {
  // Wait for page to be fully loaded before measuring
  if (document.readyState === "complete") {
    measureAllVitals(callback);
  } else {
    window.addEventListener("load", () => measureAllVitals(callback), { once: true });
  }
}

/**
 * Measure all Core Web Vitals
 */
function measureAllVitals(callback?: ReportCallback): void {
  measureLCP(callback);
  measureFID(callback);
  measureCLS(callback);
  measureFCP(callback);
  measureTTFB(callback);
  measureINP(callback);
}

/**
 * Get current performance metrics
 */
export function getPerformanceMetrics(): {
  navigation?: PerformanceNavigationTiming;
  paint?: PerformancePaintTiming[];
  resources?: PerformanceResourceTiming[];
} {
  return {
    navigation: performance.getEntriesByType("navigation")[0] as PerformanceNavigationTiming,
    paint: performance.getEntriesByType("paint") as PerformancePaintTiming[],
    resources: performance.getEntriesByType("resource") as PerformanceResourceTiming[],
  };
}

/**
 * Log performance summary to console
 */
export function logPerformanceSummary(): void {
  const metrics = getPerformanceMetrics();

  if (metrics.navigation) {
    const nav = metrics.navigation;
    console.group("📊 Performance Summary");
    console.log("DNS Lookup:", (nav.domainLookupEnd - nav.domainLookupStart).toFixed(2), "ms");
    console.log("TCP Connection:", (nav.connectEnd - nav.connectStart).toFixed(2), "ms");
    console.log("Request Time:", (nav.responseStart - nav.requestStart).toFixed(2), "ms");
    console.log("Response Time:", (nav.responseEnd - nav.responseStart).toFixed(2), "ms");
    console.log("DOM Processing:", (nav.domComplete - nav.domInteractive).toFixed(2), "ms");
    console.log("Total Load Time:", (nav.loadEventEnd - nav.fetchStart).toFixed(2), "ms");
    console.groupEnd();
  }

  if (metrics.paint && metrics.paint.length > 0) {
    console.group("🎨 Paint Metrics");
    metrics.paint.forEach((entry) => {
      console.log(`${entry.name}:`, entry.startTime.toFixed(2), "ms");
    });
    console.groupEnd();
  }
}

export default initWebVitals;
