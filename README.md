# Financial LF

Aplicativo Flutter para planejamento financeiro mensal offline.

## Funcionalidades

- 📊 **Planejamento Mensal**: Visualize saldos previstos por mês
- 💰 **Gestão de Salários**: Histórico de salários com períodos
- 💳 **Cartões de Crédito**: Gerencie cartões e suas faturas
- 📝 **Gastos e Receitas**: Registre gastos e receitas por categoria
- 🔄 **Gastos Fixos**: Cadastre gastos recorrentes que se aplicam automaticamente
- 📈 **Relatórios**: Visualize saldos acumulados por ano e mês
- 👤 **Perfil**: Configure informações pessoais e saldo inicial

## Tecnologias

- Flutter
- Drift (SQLite)
- Riverpod (State Management)
- Material 3

## Requisitos

- Flutter SDK 3.0+
- Dart 3.0+

## Instalação

```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter run
```

## Estrutura do Projeto

```
lib/
├── core/           # Providers e configurações
├── data/           # Repositórios e banco de dados
├── domain/         # Modelos de domínio
└── presentation/   # Telas e widgets
```

## Licença

Este projeto é privado.
