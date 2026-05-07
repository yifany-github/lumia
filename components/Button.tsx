import React from 'react';
import { ButtonVariant } from '../types';

interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant;
  children: React.ReactNode;
  className?: string;
}

const Button: React.FC<ButtonProps> = ({ 
  variant = ButtonVariant.PRIMARY, 
  children, 
  className = '', 
  ...props 
}) => {
  const baseStyles = "inline-flex items-center justify-center rounded-full font-bold transition-all duration-300 active:scale-95 disabled:opacity-50 disabled:pointer-events-none";
  
  const sizes = "h-12 px-8 text-base"; // Standard size based on design system

  const variants = {
    [ButtonVariant.PRIMARY]: "bg-primary text-primary-foreground shadow-[0_4px_20px_-2px_rgba(93,112,82,0.15)] hover:shadow-[0_6px_24px_-4px_rgba(93,112,82,0.25)] hover:scale-105",
    [ButtonVariant.OUTLINE]: "border-2 border-secondary text-secondary bg-transparent hover:bg-secondary/5 hover:scale-105",
    [ButtonVariant.GHOST]: "bg-transparent text-primary hover:bg-primary/10 hover:scale-105",
  };

  return (
    <button 
      className={`${baseStyles} ${sizes} ${variants[variant]} ${className}`}
      {...props}
    >
      {children}
    </button>
  );
};

export default Button;