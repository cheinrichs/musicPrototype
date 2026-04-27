import '../audio/note.dart';

class SolfegeNote {
  final Note note;
  final String solfege;

  const SolfegeNote(this.note, this.solfege);

  static const List<SolfegeNote> cMajorScale = [
    SolfegeNote(Note.c4, 'Do'),
    SolfegeNote(Note.d4, 'Re'),
    SolfegeNote(Note.e4, 'Mi'),
    SolfegeNote(Note.f4, 'Fa'),
    SolfegeNote(Note.g4, 'Sol'),
    SolfegeNote(Note.a4, 'La'),
    SolfegeNote(Note.b4, 'Ti'),
  ];
}
