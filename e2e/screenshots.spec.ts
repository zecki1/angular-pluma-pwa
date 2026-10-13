import { test, type Page } from '@playwright/test';
import { mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { garantirSessao } from './apoio/sessao';

const PAGINAS = [
  { path: '/login', nome: 'login' },
  { path: '/dashboard', nome: 'dashboard' },
  { path: '/transacoes', nome: 'transacoes' },
  { path: '/configuracoes', nome: 'configuracoes' },
];

const VIEWPORTS = [
  { nome: 'desktop', width: 1440, height: 900 },
  { nome: 'mobile', width: 390, height: 844 },
];

const SAIDA = join('docs', 'screenshots');

/** Espera a rede e as animações de entrada assentarem antes do print. */
async function aguardarEstabilizar(page: Page): Promise<void> {
  await page.waitForLoadState('networkidle');
  await page.waitForTimeout(600);
}

test.describe('screenshots (baselines do README)', () => {
  test.setTimeout(180_000);

  test.beforeEach(async ({ page }) => {
    await garantirSessao(page);
  });

  for (const viewport of VIEWPORTS) {
    test.describe(viewport.nome, () => {
      test.use({ viewport: { width: viewport.width, height: viewport.height } });

      for (const pagina of PAGINAS) {
        test(`${pagina.nome} ${viewport.nome}`, async ({ page }) => {
          mkdirSync(SAIDA, { recursive: true });
          await page.goto(pagina.path);
          await aguardarEstabilizar(page);

          await page.screenshot({
            path: join(SAIDA, `${pagina.nome}-${viewport.nome}.jpg`),
            fullPage: true,
            type: 'jpeg',
            quality: 80,
          });
        });
      }
    });
  }
});
