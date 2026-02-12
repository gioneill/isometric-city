const { withGTConfig } = require("gt-next/config");

const isIosBundle = process.env.ISOCITY_IOS_BUNDLE === "1";

/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  reactCompiler: true,
  ...(isIosBundle
    ? {
        output: "export",
        trailingSlash: true,
        images: { unoptimized: true },
      }
    : {}),
};

module.exports = withGTConfig(nextConfig);
