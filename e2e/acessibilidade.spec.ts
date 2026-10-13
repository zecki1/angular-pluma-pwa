import { expect, test } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { garantirSessao } from './apoio/sessao';

/**
 * Rotas reais do app. `''` é um redirect para `/login`, por isso não aparece
 * como página própria. Todas são telas do scaffold (Shell + página).
 */
const PAGINAS = [
  { path: '/login', nome: 'login' },
  { path: '/dashboard', nome: 'dashboard' },
  { path: '/transacoes', nome: 'transacoes' },
  { path: '/configuracoes', nome: 'configuracoes' },
];

test.describe('acessibilidade (axe)', () => {
  test.setTimeout(180_000);

  test.beforeEach(async ({ page }) => {
    await garantirSessao(page);
  });

  test('gera relatório e falha em violações graves/críticas', async ({ page }) => {
    const relatorio: Array<Record<string, unknown>> = [];

    for (const pagina of PAGINAS) {
      await page.goto(pagina.path);
      await page.waitForLoadState('networkidle');

      const resultados = await new AxeBuilder({ page })
        .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'])
        .analyze();

      const graves = resultados.violations.filter(
        (v) => v.impact === 'serious' || v.impact === 'critical',
      );

      relatorio.push({
        pagina: pagina.nome,
        url: pagina.path,
        violacoes: resultados.violations.map((v) => ({
          id: v.id,
          impact: v.impact,
          descricao: v.help,
          nos: v.nodes.length,
        })),
        passes: resultados.passes.length,
        graves: graves.length,
      });

      expect(
        graves,
        `violações graves/críticas em ${pagina.path}: ${graves.map((v) => v.id).join(', ')}`,
      ).toEqual([]);
    }

    mkdirSync('docs/a11y', { recursive: true });
    writeFileSync(
      join('docs/a11y', 'relatorio-axe.json'),
      `${JSON.stringify(relatorio, null, 2)}\n`,
      'utf8',
    );
  });
});
