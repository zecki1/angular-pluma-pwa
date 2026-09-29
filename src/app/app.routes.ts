import { Routes } from '@angular/router';
import { LoginPage } from './pages/login/login';
import { DashboardPage } from './pages/dashboard/dashboard';
import { TransacoesPage } from './pages/transacoes/transacoes';
import { ConfiguracoesPage } from './pages/configuracoes/configuracoes';
export const routes: Routes = [
  { path: '', pathMatch: 'full', redirectTo: 'login' },
  { path: 'login', component: LoginPage, title: 'Login — Pluma' },
  { path: 'dashboard', component: DashboardPage, title: 'Dashboard — Pluma' },
  { path: 'transacoes', component: TransacoesPage, title: 'Transacoes — Pluma' },
  { path: 'configuracoes', component: ConfiguracoesPage, title: 'Configuracoes — Pluma' },
  { path: '**', redirectTo: 'login' },
];
