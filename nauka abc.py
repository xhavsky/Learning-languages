import tkinter as tk
from tkinter import messagebox
import random
import json
import os

KATALOG_PROGRAMU = os.path.dirname(os.path.abspath(__file__))
PLIK_BAZY = os.path.join(KATALOG_PROGRAMU, "baza_rosyjski.json")

# Bogata baza startowa do języka rosyjskiego
baza_domyslna = {
    "Rosyjski": [
        {"pl": "być", "obcy": "быть", "nauczone": False},
        {"pl": "mieć", "obcy": "иметь", "nauczone": False},
        {"pl": "mówić", "obcy": "говорить", "nauczone": False},
        {"pl": "kochać", "obcy": "любить", "nauczone": False},
        {"pl": "wiedzieć", "obcy": "знать", "nauczone": False},
        {"pl": "myśleć", "obcy": "думать", "nauczone": False},
        {"pl": "robić", "obcy": "делать", "nauczone": False},
        {"pl": "chcieć", "obcy": "хотеть", "nauczone": False},
        {"pl": "iść", "obcy": "идти", "nauczone": False},
        {"pl": "widzieć", "obcy": "видеть", "nauczone": False},
        {"pl": "dzień", "obcy": "день", "nauczone": False},
        {"pl": "czas", "obcy": "время", "nauczone": False},
        {"pl": "człowiek", "obcy": "человек", "nauczone": False},
        {"pl": "rok", "obcy": "год", "nauczone": False},
        {"pl": "życie", "obcy": "жизнь", "nauczone": False},
        {"pl": "ręka", "obcy": "рука", "nauczone": False},
        {"pl": "słowo", "obcy": "слово", "nauczone": False},
        {"pl": "głowa", "obcy": "голова", "nauczone": False},
        {"pl": "dom", "obcy": "дом", "nauczone": False},
        {"pl": "miasto", "obcy": "город", "nauczone": False},
        {"pl": "tak", "obcy": "да", "nauczone": False},
        {"pl": "nie", "obcy": "нет", "nauczone": False},
        {"pl": "dziękuję", "obcy": "спасибо", "nauczone": False},
        {"pl": "proszę", "obcy": "пожалуйста", "nauczone": False},
        {"pl": "dzień dobry", "obcy": "здравствуйте", "nauczone": False},
        {"pl": "cześć", "obcy": "привет", "nauczone": False},
        {"pl": "do widzenia", "obcy": "до свидания", "nauczone": False},
        {"pl": "dobrze", "obcy": "хорошо", "nauczone": False},
        {"pl": "źle", "obcy": "плохо", "nauczone": False},
        {"pl": "nowy", "obcy": "новый", "nauczone": False},
        {"pl": "stary", "obcy": "старый", "nauczone": False},
        {"pl": "duży", "obcy": "большой", "nauczone": False},
        {"pl": "mały", "obcy": "маленький", "nauczone": False},
        {"pl": "piękny", "obcy": "красивый", "nauczone": False},
        {"pl": "przyjaciel", "obcy": "друг", "nauczone": False},
        {"pl": "chleb", "obcy": "хлеб", "nauczone": False},
        {"pl": "woda", "obcy": "вода", "nauczone": False},
        {"pl": "herbata", "obcy": "чай", "nauczone": False},
        {"pl": "kawa", "obcy": "кофе", "nauczone": False},
        {"pl": "obiad", "obcy": "обед", "nauczone": False}
    ]
}

def wczytaj_baze():
    if os.path.exists(PLIK_BAZY):
        try:
            with open(PLIK_BAZY, "r", encoding="utf-8") as f:
                return json.load(f)
        except:
            return baza_domyslna
    return baza_domyslna

def zapisz_baze(baza):
    with open(PLIK_BAZY, "w", encoding="utf-8") as f:
        json.dump(baza, f, ensure_ascii=False, indent=4)

baza_slowek = wczytaj_baze()

class OknoDodawania(tk.Toplevel):
    def __init__(self, parent, odswiez_callback):
        super().__init__(parent)
        self.title("Dodaj rosyjskie słówko")
        self.geometry("550x450")
        self.odswiez_callback = odswiez_callback
        
        tk.Label(self, text="Słowo po polsku:", font=("Arial", 11)).pack(pady=5)
        self.entry_pl = tk.Entry(self, font=("Arial", 12), width=30)
        self.entry_pl.pack()
        
        tk.Label(self, text="Tłumaczenie po rosyjsku (użyj klawiatury poniżej lub pisz):", font=("Arial", 11)).pack(pady=5)
        self.entry_obcy = tk.Entry(self, font=("Arial", 14), width=30, justify="center")
        self.entry_obcy.pack()
        self.entry_obcy.focus_set()
        
        # Ekranowa klawiatura rosyjska (Cyrylica)
        frame_klawiatura = tk.Frame(self)
        frame_klawiatura.pack(pady=10)
        
        uklad_liter = [
            ['Й', 'Ц', 'У', 'К', 'Е', 'Н', 'Г', 'Ш', 'Щ', 'З', 'Х', 'Ъ'],
            ['Ф', 'Ы', 'В', 'А', 'П', 'Р', 'О', 'Л', 'Д', 'Ж', 'Э'],
            ['Я', 'Ч', 'С', 'М', 'И', 'Т', 'Ь', 'Б', 'Ю', 'Ё']
        ]
        
        for wiersz in uklad_liter:
            frame_wiersz = tk.Frame(frame_klawiatura)
            frame_wiersz.pack()
            for litera in wiersz:
                btn = tk.Button(frame_wiersz, text=litera.lower(), width=3, height=1, font=("Arial", 11),
                                command=lambda l=litera.lower(): self.wstaw_litere(l))
                btn.pack(side=tk.LEFT, padx=2, pady=2)
                
        # Przyciski pomocnicze klawiatury
        frame_kontrolne = tk.Frame(self)
        frame_kontrolne.pack(pady=5)
        tk.Button(frame_kontrolne, text="Spacja", width=15, command=lambda: self.wstaw_litere(" ")).pack(side=tk.LEFT, padx=5)
        tk.Button(frame_kontrolne, text="Cofnij (←)", width=10, bg="#ffc107", command=self.cofnij_litere).pack(side=tk.LEFT, padx=5)

        tk.Button(self, text="Zapisz na stałe", command=self.zapisz, bg="#2196F3", fg="white", font=("Arial", 12, "bold"), width=20).pack(pady=15)
        
    def wstaw_litere(self, litera):
        self.entry_obcy.insert(tk.END, litera)
        
    def cofnij_litere(self):
        tekst = self.entry_obcy.get()
        if tekst:
            self.entry_obcy.delete(len(tekst)-1, tk.END)

    def zapisz(self):
        pl = self.entry_pl.get().strip()
        obcy = self.entry_obcy.get().strip()
        
        if pl and obcy:
            baza_slowek["Rosyjski"].append({"pl": pl, "obcy": obcy, "nauczone": False})
            zapisz_baze(baza_slowek)
            messagebox.showinfo("Sukces", f"Dodano: {obcy} = {pl}")
            self.odswiez_callback()
            self.destroy()
        else:
            messagebox.showwarning("Błąd", "Wypełnij oba pola!")

class AplikacjaNauka:
    def __init__(self, root):
        self.root = root
        self.root.title("Rosyjski ABC - Trener")
        self.root.geometry("500x480")
        
        self.tryb_nauczone = False
        self.aktualne_slowo = None
        self.poprawna_odpowiedz = ""
        
        # Pasek górny
        frame_top = tk.Frame(root)
        frame_top.pack(pady=10, fill=tk.X)
        
        tk.Button(frame_top, text="+ Dodaj rosyjskie słowo", command=self.otworz_dodawanie, bg="#FF9800", fg="white", font=("Arial", 10, "bold")).pack(side=tk.LEFT, padx=20)
        
        self.btn_tryb = tk.Button(frame_top, text="Tryb: Nauka", command=self.przelacz_tryb, bg="#E0E0E0", font=("Arial", 9, "bold"))
        self.btn_tryb.pack(side=tk.RIGHT, padx=20)
        
        self.lbl_staty = tk.Label(root, text="Do nauki: 0 | Opanowane: 0", font=("Arial", 10, "italic"))
        self.lbl_staty.pack(pady=5)
        
        # Słowo po rosyjsku
        tk.Label(root, text="Jak po polsku znaczy słowo:", font=("Arial", 12), fg="#666666").pack(pady=5)
        self.label_rosyjskie = tk.Label(root, text="...", font=("Arial", 26, "bold"), fg="#1565C0")
        self.label_rosyjskie.pack(pady=15)
        
        # Przyciski wyboru wyboru (A, B, C)
        self.warianty_przyciski = []
        for i in range(3):
            btn = tk.Button(root, text="", font=("Arial", 12), width=35, height=2, bg="#f8f9fa",
                            command=lambda idx=i: self.sprawdz_wybor(idx))
            btn.pack(pady=6)
            self.warianty_przyciski.append(btn)
            
        self.losuj_pytanie()

    def otworz_dodawanie(self):
        OknoDodawania(self.root, self.losuj_pytanie)

    def przelacz_tryb(self):
        self.tryb_nauczone = not self.tryb_nauczone
        if self.tryb_nauczone:
            self.btn_tryb.config(text="Tryb: Powtórka", bg="#9C27B0", fg="white")
        else:
            self.btn_tryb.config(text="Tryb: Nauka", bg="#E0E0E0", fg="black")
        self.losuj_pytanie()

    def losuj_pytanie(self):
        # Reset kolorów przycisków
        for btn in self.warianty_przyciski:
            btn.config(bg="#f8f9fa", state=tk.NORMAL)
            
        wgladowe = baza_slowek.get("Rosyjski", [])
        do_nauki = [s for s in wgladowe if not s.get("nauczone", False)]
        nauczone = [s for s in wgladowe if s.get("nauczone", False)]
        
        self.lbl_staty.config(text=f"Do nauki: {len(do_nauki)} | Opanowane: {len(nauczone)}")
        
        pula = nauczone if self.tryb_nauczone else do_nauki
        
        if not pula:
            self.label_rosyjskie.config(text="Brak słówek!")
            for btn in self.warianty_przyciski:
                btn.config(text="-", state=tk.DISABLED)
            return
            
        # Wybór słowa głównego (pytania)
        self.aktualne_slowo = random.choice(pula)
        self.label_rosyjskie.config(text=self.aktualne_slowo['obcy'])
        self.poprawna_odpowiedz = self.aktualne_slowo['pl']
        
        # Losowanie zmylaczy z CAŁEJ bazy (żeby zawsze były 3 opcje)
        wszystkie_pl = list(set([s['pl'] for s in wgladowe if s['pl'] != self.poprawna_odpowiedz]))
        
        if len(wszystkie_pl) < 2:
            # Awaryjnie jeśli w bazie byłoby za mało słówek
            wszystkie_pl = ["kot", "pies", "okno"]
            
        zmylacze = random.sample(wszystkie_pl, 2)
        
        # Połączenie i wymieszanie wariantów
        self.warianty = [self.poprawna_odpowiedz] + zmylacze
        random.shuffle(self.warianty)
        
        # Przypisanie tekstu do przycisków
        for i in range(3):
            self.warianty_przyciski[i].config(text=self.warianty[i])

    def sprawdz_wybor(self, idx):
        wybrany_tekst = self.warianty[idx]
        
        if wybrany_tekst == self.poprawna_odpowiedz:
            self.warianty_przyciski[idx].config(bg="#4CAF50") # Zielony za poprawną
            if not self.aktualne_slowo.get("nauczone", False):
                self.aktualne_slowo["nauczone"] = True
                zapisz_baze(baza_slowek)
            # Małe opóźnienie przed kolejnym pytaniem, żeby użytkownik zobaczył zielony kolor
            self.root.after(600, self.losuj_pytanie)
        else:
            self.warianty_przyciski[idx].config(bg="#F44336") # Czerwony za błąd
            if self.aktualne_slowo.get("nauczone", False):
                self.aktualne_slowo["nauczone"] = False
                zapisz_baze(baza_slowek)
                
            # Pokazanie podpowiedzi, która była poprawna
            for btn in self.warianty_przyciski:
                if btn.cget("text") == self.poprawna_odpowiedz:
                    btn.config(bg="#4CAF50")
            
            self.root.after(1200, self.losuj_pytanie)

if __name__ == "__main__":
    root = tk.Tk()
    app = AplikacjaNauka(root)
    root.mainloop()