import { Slot } from "@radix-ui/react-slot";
import { cva, type VariantProps } from "class-variance-authority";
import * as React from "react";
import { cn } from "@/lib/utils";
import { triggerHaptic } from "@/utils/haptics";

const buttonVariants = cva(
  "inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-md text-sm font-medium transition-all duration-200 active:scale-95 disabled:pointer-events-none disabled:opacity-50 [&_svg]:pointer-events-none [&_svg:not([class*='size-'])]:size-4 shrink-0 [&_svg]:shrink-0",
  {
    variants: {
      variant: {
        default: "bg-primary text-primary-foreground shadow-xs hover:bg-primary/90 hover:shadow-sm",
        destructive: "bg-destructive text-destructive-foreground shadow-xs hover:bg-destructive/90 hover:shadow-sm",
        outline: "border bg-background shadow-xs hover:bg-accent hover:text-accent-foreground hover:shadow-sm",
        secondary: "bg-secondary text-secondary-foreground shadow-xs hover:bg-secondary/80 hover:shadow-sm",
        ghost: "hover:bg-accent hover:text-accent-foreground",
        link: "text-primary underline-offset-4 hover:underline",
      },
      size: {
        default: "h-8 px-3",
        sm: "h-7 rounded-md gap-1 px-2 has-[>svg]:px-2",
        lg: "h-9 rounded-md px-4",
        icon: "size-8",
      },
    },
    defaultVariants: {
      variant: "default",
      size: "default",
    },
  },
);

const Button = React.forwardRef<
  HTMLButtonElement,
  React.ComponentProps<"button"> &
    VariantProps<typeof buttonVariants> & {
      asChild?: boolean;
      enableHaptic?: boolean;
    }
>(({ className, variant, size, asChild = false, enableHaptic = true, onClick, ...props }, ref) => {
  const Comp = asChild ? Slot : "button";

  const handleClick = React.useCallback(
    (e: React.MouseEvent<HTMLButtonElement>) => {
      if (enableHaptic && !props.disabled) {
        // Use appropriate haptic feedback based on variant
        const hapticType = variant === "destructive" ? "warning" : "light";
        triggerHaptic(hapticType);
      }
      onClick?.(e);
    },
    [enableHaptic, onClick, props.disabled, variant],
  );

  return (
    <Comp ref={ref} data-slot="button" className={cn(buttonVariants({ variant, size, className }))} onClick={handleClick} {...props} />
  );
});
Button.displayName = "Button";

export { Button, buttonVariants };
