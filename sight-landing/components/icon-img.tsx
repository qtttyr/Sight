"use client";

/**
 * Generated monochrome assets ship as transparent PNGs in two colorways:
 * `name.png` (dark object, for the light theme) and `name-inv.png`
 * (white object, for the dark theme). See scripts in /tmp/shotenv/process.mjs.
 */
export function IconImg({
  name,
  alt,
  className = "",
}: {
  name: string;
  alt: string;
  className?: string;
}) {
  return (
    <>
      {/* light theme: dark object */}
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        src={`/icons/${name}.png`}
        alt={alt}
        draggable={false}
        className={`icon-light select-none pointer-events-none ${className}`}
      />
      {/* dark theme: white object */}
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        src={`/icons/${name}-inv.png`}
        alt={alt}
        aria-hidden={alt === "" ? true : undefined}
        draggable={false}
        className={`icon-dark select-none pointer-events-none ${className}`}
      />
    </>
  );
}
