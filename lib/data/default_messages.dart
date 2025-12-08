// 50 numatytų žinučių su automatine rotacija
// Galite papildyti iki 365 - tiesiog pridėkite daugiau į messages Map
class DefaultMessages {
  static final Map<int, String> messages = {
    // Originalios (1-31)
    1: 'Tu esi geriausias! ❤️',
    2: 'Aš tave myliu labiau nei vakarykštę dieną',
    3: 'Tu mano stiprybė',
    4: 'Kiekviena diena su tavimi yra dovana',
    5: 'Esu laimingiausia žmogus pasaulyje',
    6: 'Mano širdis plaka greičiau, kai esi šalia',
    7: 'Tu padarai mano dieną šviesesnę',
    8: 'Aš myliu tavo šypseną',
    9: 'Tu esi mano ramybės uostas',
    10: 'Su tavimi jaučiuosi pilnai',
    11: 'Tu esi mano sapnas, kuris išsipildė',
    12: 'Aš myliu tavo gerumą',
    13: 'Tu esi mano didžiausias laimėjimas',
    14: 'Su tavimi viskas įmanoma',
    15: 'Aš myliu tave daugiau nei žodžiai gali apibūdinti',
    16: 'Tu esi mano viskas',
    17: 'Kiekviena akimirka su tavimi yra brangi',
    18: 'Aš myliu tavo būdą',
    19: 'Tu esi mano saulė',
    20: 'Su tavimi esu pats savimi',
    21: 'Aš myliu tavo širdį',
    22: 'Tu esi mano atrama',
    23: 'Kiekvieną dieną dėkoju už tave',
    24: 'Aš myliu tavo dvasią',
    25: 'Tu esi mano herojus',
    26: 'Su tavimi jaučiuosi saugus',
    27: 'Aš myliu tavo ambicijas',
    28: 'Tu esi mano įkvėpimas',
    29: 'Kiekvieną rytą džiaugiuosi, kad esi mano gyvenime',
    30: 'Aš myliu tavo ryžtą',
    31: 'Tu esi mano partneris viskam',

    // Papildomos (32-50)
    32: 'Tavo buvimas man suteikia jėgų 💪',
    33: 'Esi mano laimės šaltinis ☀️',
    34: 'Dėkoju likimui, kad tave sutikau',
    35: 'Tu darai mane geresniu žmogumi',
    36: 'Mano diena prasideda nuo tavęs',
    37: 'Su tavimi jaučiuosi namie 🏠',
    38: 'Tavo meilė - mano didžiausia dovana',
    39: 'Kiekviena akimirka su tavimi yra tobula',
    40: 'Tu esi mano svajonė, tapusi tikrove',
    41: 'Myliu tave labiau nei vakar, mažiau nei rytoj',
    42: 'Tu esi mano gyvenimo prasmė',
    43: 'Šalia tavęs jaučiuosi stiprus',
    44: 'Tavo šypsena nušviečia mano dieną ✨',
    45: 'Esi mano didžiausia palaima',
    46: 'Su tavimi viskas įgauna spalvų 🌈',
    47: 'Tu esi mano saugus uostas audroje',
    48: 'Myliu kiekvieną akimirką su tavimi',
    49: 'Tu man esi viskas, ko reikia',
    50: 'Mano meilė tau auga kiekvieną dieną 💕',
  };

  // Gauti žinutę pagal dienos numerį
  static String getMessage(int dayNumber) {
    // 🛡️ Validuoti dienos numerį
    if (dayNumber < 1 || dayNumber > 365) {
      return 'Aš tave myliu! 💖'; // Default fallback
    }

    // Jei yra konkreti žinutė šiai dienai - grąžinti ją
    if (messages.containsKey(dayNumber)) {
      final message = messages[dayNumber]!;
      // 🛡️ Patikrinti ar žinutė nėra tuščia
      return message.isNotEmpty ? message : 'Aš tave myliu! 💖';
    }

    // Jei nėra - naudoti rotaciją
    final totalMessages = messages.length;
    if (totalMessages == 0) {
      return 'Aš tave myliu! 💖';
    }

    final rotatedIndex = ((dayNumber - 1) % totalMessages) + 1;
    return messages[rotatedIndex] ?? 'Aš tave myliu! 💖';
  }

  // Helper funkcija - grąžina visų žinučių kiekį
  static int get totalMessages {
    // 🛡️ Patikrinti ar nėra tuščių žinučių
    final validMessages = messages.values.where((msg) => msg.isNotEmpty);
    return validMessages.length;
  }

  // Helper funkcija - patikrinti ar yra custom žinutė šiai dienai
  static bool hasMessageForDay(int dayNumber) {
    if (dayNumber < 1 || dayNumber > 365) return false;
    return messages.containsKey(dayNumber) && messages[dayNumber]!.isNotEmpty;
  }
}
