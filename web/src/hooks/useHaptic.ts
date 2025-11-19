import { useCallback } from "react";
import { HapticFeedbackType, triggerHaptic } from "@/utils/haptics";

/**
 * Custom hook for haptic feedback
 * @returns Haptic feedback functions
 */
export function useHaptic() {
  const haptic = useCallback((type: HapticFeedbackType = "light") => {
    triggerHaptic(type);
  }, []);

  const hapticTap = useCallback(() => triggerHaptic("light"), []);
  const hapticSelection = useCallback(() => triggerHaptic("selection"), []);
  const hapticSuccess = useCallback(() => triggerHaptic("success"), []);
  const hapticError = useCallback(() => triggerHaptic("error"), []);
  const hapticWarning = useCallback(() => triggerHaptic("warning"), []);

  return {
    haptic,
    hapticTap,
    hapticSelection,
    hapticSuccess,
    hapticError,
    hapticWarning,
  };
}

export default useHaptic;
