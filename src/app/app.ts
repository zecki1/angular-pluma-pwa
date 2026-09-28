import { Component, inject, signal } from '@angular/core';
import { RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { SupabaseService } from './core/supabase';

interface ItemNav {
  path: string;
  rotulo: string;
}

@Component({
  selector: 'app-root',
  imports: [RouterOutlet, RouterLink, RouterLinkActive],
  templateUrl: './app.html',
  styleUrl: './app.css',
})
export class App {
  private readonly supabase = inject(SupabaseService);

  protected readonly titulo = 'Pluma';
  protected readonly tagline = 'App financeiro offline-first — service worker, cache e instalação';
  protected readonly semana = 7;
  protected readonly nav: ItemNav[] = [
    { path: '/login', rotulo: 'Login' },
    { path: '/dashboard', rotulo: 'Dashboard' },
    { path: '/transacoes', rotulo: 'Transacoes' },
    { path: '/configuracoes', rotulo: 'Configuracoes' },
  ];

  protected readonly menuAberto = signal(false);
  protected readonly modoDemo = this.supabase.modoDemo;
  protected readonly erro = this.supabase.erro;

  protected alternarMenu(): void {
    this.menuAberto.update((v) => !v);
  }
}
