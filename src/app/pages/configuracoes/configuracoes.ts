import { Component, inject, signal } from '@angular/core';
import { SupabaseService } from '../../core/supabase';

@Component({
  selector: 'app-configuracoes',
  templateUrl: './configuracoes.html',
  styleUrl: './configuracoes.css',
})
export class ConfiguracoesPage {
  private readonly supabase = inject(SupabaseService);

  protected readonly titulo = 'Configuracoes';
  protected readonly descricao = 'Estado do service worker e instalação A2HS.';
  protected readonly slugProjeto = 'pluma';

  protected readonly conectando = signal(false);
  protected readonly conexaoOk = signal<boolean | null>(null);

  /** Health-check contra o projeto Supabase compartilhado. */
  protected async verificar(): Promise<void> {
    this.conectando.set(true);
    this.conexaoOk.set(await this.supabase.verificarConexão());
    this.conectando.set(false);
  }
}
