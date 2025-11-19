/**
 * Haptic feedback utilities for mobile devices
 * Provides tactile feedback for user interactions
 */

export type HapticFeedbackType = "light" | "medium" | "heavy" | "selection" | "success" | "warning" | "error";

/**
 * Check if haptic feedback is supported
 */
export const isHapticSupported = (): boolean => {
  return "vibrate" in navigator || ("Notification" in window && "vibrate" in navigator);
};

/**
 * Trigger haptic feedback
 * @param type - Type of haptic feedback
 */
export const triggerHaptic = (type: HapticFeedbackType = "light"): void => {
  if (!isHapticSupported()) {
    return;
  }

  // Map haptic types to vibration patterns (in milliseconds)
  const patterns: Record<HapticFeedbackType, number | number[]> = {
    light: 10,
    medium: 20,
    heavy: 30,
    selection: 5,
    success: [10, 50, 10],
    warning: [20, 50, 20],
    error: [30, 50, 30, 50, 30],
  };

  const pattern = patterns[type];

  try {
    if (navigator.vibrate) {
      navigator.vibrate(pattern);
    }
  } catch (error) {
    // Silently fail if vibration is not supported
    console.debug("Haptic feedback not available:", error);
  }
};

/**
 * Trigger haptic feedback on tap/click
 */
export const hapticTap = () => triggerHaptic("light");

/**
 * Trigger haptic feedback on selection
 */
export const hapticSelection = () => triggerHaptic("selection");

/**
 * Trigger haptic feedback on success
 */
export const hapticSuccess = () => triggerHaptic("success");

/**
 * Trigger haptic feedback on error
 */
export const hapticError = () => triggerHaptic("error");

/**
 * Trigger haptic feedback on warning
 */
export const hapticWarning = () => triggerHaptic("warning");

/**
 * Create a haptic-enabled event handler
 * @param handler - Original event handler
 * @param hapticType - Type of haptic feedback
 * @returns Enhanced event handler with haptic feedback
 */
export const withHaptic = <T extends (...args: any[]) => any>(handler: T, hapticType: HapticFeedbackType = "light"): T => {
  return ((...args: any[]) => {
    triggerHaptic(hapticType);
    return handler(...args);
  }) as T;
};
