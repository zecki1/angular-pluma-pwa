import type { Page } from '@playwright/test';

/**
 * Credenciais de demo (sobrescrevíveis por env var) usadas quando o app expõe
 * um formulário de login real em `/login`.
 */
const EMAIL_DEMO = process.env['E2E_EMAIL'] ?? 'user@demo.dev';
const SENHA_DEMO = process.env['E2E_SENHA'] ?? 'demo1234';

/**
 * Garante uma sessão autenticada antes de acessar as telas internas.
 *
 * No scaffold atual do Pluma as rotas não têm guard e `/login` é apenas um
 * health-check do Supabase (não há formulário de senha), então a navegação
 * direta funciona e esta função é um no-op. Quando a autenticação real entrar
 * (input de senha em `/login`), o helper preenche o login demo e espera sair
 * da tela de login — mantendo os specs de a11y e de prints prontos para o
 * app autenticado.
 */
export async function garantirSessao(page: Page): Promise<void> {
  await page.goto('/login');

  const campoSenha = page.locator('input[type="password"]');
  if ((await campoSenha.count()) === 0) {
    // Scaffold sem formulário de login — as telas internas são acessíveis.
    return;
  }

  await page
    .locator('input[type="email"], input[name="email"], input#email')
    .first()
    .fill(EMAIL_DEMO)
    .catch(() => undefined);
  await campoSenha.first().fill(SENHA_DEMO);
  await page
    .getByRole('button', { name: /entrar|login|acessar/i })
    .first()
    .click();

  await page.waitForURL((url) => !url.pathname.endsWith('/login'), { timeout: 10_000 });
}
