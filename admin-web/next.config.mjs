/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  webpack: (config, { isServer }) => {
    config.externals = [...(config.externals || []), 'jspdf', 'html2canvas'];
    config.resolve = {
      ...config.resolve,
      fallback: {
        ...config.resolve?.fallback,
        'crypto': false,
      },
    };
    return config;
  },
};

export default nextConfig;

