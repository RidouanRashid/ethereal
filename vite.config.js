import { defineConfig } from 'vite';

export default defineConfig({
  // './' zorgt dat de build in elke map werkt, dus ook op http://localhost/etheral/.
  base: './',
  build: {
    rollupOptions: {
      output: {
        // Vaste bestandsnamen: een nieuwe build overschrijft de oude,
        // zodat er geen verouderde bestanden in dist/ achterblijven.
        entryFileNames: 'assets/app.js',
        chunkFileNames: 'assets/[name].js',
        assetFileNames: 'assets/[name][extname]',
      },
    },
  },
});
