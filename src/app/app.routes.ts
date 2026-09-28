import { Routes } from '@angular/router';
import login from './pages/login';
import dashboard from './pages/dashboard';
import transacoes from './pages/transacoes';
import configuracoes from './pages/configuracoes';

export const routes: Routes = [
  { path: '', pathMatch: 'full', redirectTo: 'login' },
  { path: 'login', component: login, title: 'Login — Pluma' },
  { path: 'dashboard', component: dashboard, title: 'Dashboard — Pluma' },
  { path: 'transacoes', component: transacoes, title: 'Transacoes — Pluma' },
  { path: 'configuracoes', component: configuracoes, title: 'Configuracoes — Pluma' },
  { path: '**', redirectTo: 'login' },
];
