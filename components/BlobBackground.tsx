import React from 'react';

interface BlobBackgroundProps {
  className?: string;
  variant?: 'moss' | 'terracotta' | 'sand';
  delay?: number;
}

const BlobBackground: React.FC<BlobBackgroundProps> = ({ 
  className = '', 
  variant = 'moss',
  delay = 0 
}) => {
  const colors = {
    moss: 'bg-primary',
    terracotta: 'bg-secondary',
    sand: 'bg-accent',
  };

  const style = {
    animationDelay: `${delay}s`,
  };

  return (
    <div 
      className={`absolute rounded-full mix-blend-multiply dark:mix-blend-soft-light filter blur-3xl opacity-30 dark:opacity-15 animate-blob ${colors[variant]} ${className}`}
      style={style}
    />
  );
};

export default BlobBackground;