import { defineConfig, devices } from '@playwright/test';

/**
 * Configuração do Playwright — E2E de acessibilidade (axe) e baselines do README.
 *
 * A porta é configurável por `E2E_BASE_URL` para não colidir com outras sessões
 * que também usam a 4200: suba o app numa porta dedicada e aponte para ela
 * (`E2E_BASE_URL=http://localhost:4330 npm run e2e`). Sem a variável, o próprio
 * Playwright sobe o `npm start` na 4200.
 */
export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env['CI'],
  retries: process.env['CI'] ? 2 : 0,
  workers: process.env['CI'] ? 1 : 2,
  timeout: 60_000,
  expect: { timeout: 10_000 },
  reporter: process.env['CI']
    ? [['html', { open: 'never', outputFolder: 'playwright-report' }], ['list']]
    : 'list',
  use: {
    baseURL: process.env['E2E_BASE_URL'] || 'http://localhost:4200',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    locale: 'pt-BR',
    reducedMotion: 'no-preference',
  },
  projects: [{ name: 'desktop', use: { ...devices['Desktop Chrome'] } }],
  webServer: process.env['E2E_BASE_URL']
    ? undefined
    : {
        command: 'npm start',
        url: 'http://localhost:4200',
        reuseExistingServer: !process.env['CI'],
        timeout: 120_000,
      },
});
