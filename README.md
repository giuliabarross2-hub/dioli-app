# DIOLI – Agenda

Aplicativo interno de agenda do DIOLI – Studio de Beleza.

## O que já está incluído

- Abre diretamente na Agenda, sem login e sem página inicial.
- Profissionais: GIULIA (azul) e TUANI (rosa).
- Visualizações: Dia, Três dias, Semana e Mês.
- Agenda em blocos de horário.
- Novo agendamento e edição.
- Cliente como texto livre (não existe cadastro separado de clientes).
- Serviço, profissional, data, horário, duração e observação.
- Duração padrão de 30 minutos quando não houver serviço selecionado.
- Sinal pago, valor e forma de pagamento.
- Cores manuais para os agendamentos.
- Arrastar verticalmente para alterar o horário.
- Arrastar a parte inferior do agendamento para alterar a duração.
- Pesquisa por cliente ou serviço.
- Cadastro/edição de serviços.
- Financeiro com total, sinais e pendências.
- Dados salvos localmente no aparelho com SharedPreferences.

## Como abrir

1. Instale o Flutter no computador.
2. Extraia esta pasta.
3. No terminal, entre na pasta do projeto.
4. Rode:
   flutter pub get
5. Depois:
   flutter run

Para Android, abra um emulador Android ou conecte um celular com depuração USB.
Para iPhone/iOS, é necessário ambiente macOS/Xcode para compilar o aplicativo.

## Observação importante

Esta primeira versão usa armazenamento local. Isso significa que os dados ficam no aparelho em que o app está instalado.

Se o app for usado simultaneamente em dois aparelhos (por exemplo, um aparelho da Giulia e outro da Tuani), o próximo passo é conectar um banco online, como Supabase, para que os dois vejam os mesmos agendamentos em tempo real.

A funcionalidade de arrastar e redimensionar já está implementada na agenda, mas pode ser refinada depois para ficar ainda mais parecida com o Google Calendar.
