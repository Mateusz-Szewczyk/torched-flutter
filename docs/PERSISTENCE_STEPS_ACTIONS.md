# Persystencja kroków agenta i akcji nawigacji

## Opis

Ta implementacja dodaje możliwość zapisywania i wyświetlania kroków wykonywanych przez agenta AI oraz akcji nawigacji (utworzone fiszki/egzaminy) dla każdej wiadomości bota. Po odświeżeniu strony te informacje są pobierane z bazy danych i wyświetlane obok odpowiednich wiadomości.

## Zmiany w kodzie

### Backend (RAG)

1. **`src/models.py`** - Model `Message` ma pole `meta_json` (TEXT, nullable)
   - Uwaga: Nazwa `metadata` jest zarezerwowana w SQLAlchemy Declarative API, dlatego używamy `meta_json`

2. **`src/schemas.py`** - Dodane:
   - `MessageStepSchema` - schemat dla kroku procesu
   - `MessageActionSchema` - schemat dla akcji nawigacji
   - `MessageMetadataSchema` - schemat dla całości metadata
   - Pole `metadata: Optional[str]` w `MessageCreate` i `MessageRead`
   - `MessageRead` używa `validation_alias='meta_json'` aby mapować z DB na API

3. **`src/routers/chats.py`** - Endpoint `create_message` zapisuje pole `meta_json`

### Frontend (Flutter)

1. **`lib/models/models.dart`** - Dodane nowe modele Freezed:
   - `MessageStep` - reprezentuje krok procesu
   - `MessageAction` - reprezentuje akcję nawigacji
   - `MessageMetadata` - kontener na steps i actions
   - Rozszerzenie `MessageExtension` z getterami `parsedMetadata`, `hasActions`, `hasSteps`
   - Pole `metadata: String?` w modelu `Message`

2. **`lib/services/chat_service.dart`** - 
   - `fetchMessages` - parsuje pole `metadata` z odpowiedzi
   - `saveMessage` - przyjmuje opcjonalny parametr `metadata`

3. **`lib/providers/conversation_provider.dart`** - 
   - `sendMessage` zbiera kroki i akcje podczas streamingu
   - Po zakończeniu streamingu zapisuje je jako JSON w polu `metadata`

4. **`lib/screens/chat_screen.dart`** - 
   - Dla ostatniej wiadomości: wyświetla live steps/actions
   - Dla starszych wiadomości: parsuje i wyświetla z `metadata`
   - Nowe widgety: `_PersistedStepsPanel`, `_PersistedActionsWidget`

## Migracja bazy danych

Dla istniejących baz danych uruchom:

```sql
ALTER TABLE messages ADD COLUMN IF NOT EXISTS meta_json TEXT;
```

Plik migracji: `rag/data/migrations/001_add_message_metadata.sql`

## Format metadata

```json
{
  "steps": [
    {"content": "Analizuję Twoje zapytanie...", "status": "complete"},
    {"content": "Przeszukuję bazę wiedzy...", "status": "complete"}
  ],
  "actions": [
    {"type": "flashcards", "id": 123, "name": "Nowe fiszki", "count": 20}
  ]
}
```

## Uruchomienie

### Backend
```bash
cd torch-ed/rag
# Jeśli istniejąca baza danych - uruchom migrację
python -c "from src.database import engine; engine.execute('ALTER TABLE messages ADD COLUMN IF NOT EXISTS meta_json TEXT')"
```

### Frontend
```bash
cd frontend-flutter
flutter pub run build_runner build --delete-conflicting-outputs
flutter run
```

## Flow danych

1. **Streaming** - Agent wysyła eventy `step` i `action` przez SSE
2. **Zbieranie** - Provider zbiera kroki i akcje w listach
3. **Zapisywanie** - Po `done` tworzy JSON i zapisuje jako `metadata` wiadomości bota (mapowane do `meta_json` w DB)
4. **Ładowanie** - Przy ponownym otwarciu konwersacji, wiadomości są pobierane z bazy z `meta_json` (mapowane do `metadata` w API)
5. **Wyświetlanie** - Widget parsuje JSON i renderuje panel kroków/przycisków akcji

