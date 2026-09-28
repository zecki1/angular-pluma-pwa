import { Component, inject, signal } from '@angular/core';
import { SupabaseService } from '../../core/supabase';

@Component({
  selector: 'app-transacoes',
  templateUrl: './transacoes.html',
  styleUrl: './transacoes.css',
})
export class TransacoesPage {
  private readonly supabase = inject(SupabaseService);

  protected readonly titulo = 'Transacoes';
  protected readonly descricao = 'Histórico paginado a partir do cache local.';
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
