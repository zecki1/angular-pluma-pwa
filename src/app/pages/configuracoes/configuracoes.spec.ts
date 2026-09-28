import { TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { ConfiguracoesPage } from './configuracoes';

describe('ConfiguracoesPage', () => {
  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [ConfiguracoesPage],
      providers: [provideRouter([])],
    });
  });

  it('deve criar e expor o título da página', () => {
    const fixture = TestBed.createComponent(ConfiguracoesPage);
    expect(fixture.componentInstance.titulo).toBe('Configuracoes');
  });
});
