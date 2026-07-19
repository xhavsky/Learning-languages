import tkinter as tk
from tkinter import messagebox
import random
import json
import os

KATALOG_PROGRAMU = os.path.dirname(os.path.abspath(__file__))
PLIK_BAZY = os.path.join(KATALOG_PROGRAMU, "baza_rosyjski.json")

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
    def __init__(self, parent, odswiez_callback, wstaw_funkcja):
        super().__init__(parent)
        self.title("Dodaj rosyjskie słówko")
        self.geometry("400x250")
        self.odswiez_callback = odswiez_callback
        self.wstaw_funkcja = wstaw_funkcja
        
        tk.Label(self, text="Słowo po polsku:", font=("Arial", 11)).pack(pady=5)
        self.entry_pl = tk.Entry(self, font=("Arial", 12), width=30)
        self.entry_pl.pack()
        
        tk.Label(self, text="Tłumaczenie po rosyjsku (wpisz lub użyj klawiatury na dole):", font=("Arial", 11)).pack(pady=5)
        self.entry_obcy = tk.Entry(self, font=("Arial", 14), width=30, justify="center")
        self.entry_obcy.pack()
        self.entry_obcy.focus_set()
        
        # Rejestrujemy to pole w oknie głównym, żeby dolna klawiatura pisała tutaj, póki okno jest otwarte
        self.wstaw_funkcja(self.entry_obcy)
        
        tk.Button(self, text="Zapisz na stałe", command=self.zapisz, bg="#2196F3", fg="white", font=("Arial", 12, "bold"), width=20).pack(pady=15)
        
    def zapisz(self):
        pl = self.entry_pl.get().strip()
        obcy = self.entry_obcy.get().strip()
        
        if pl and obcy:
            baza_slowek["Rosyjski"].append({"pl": pl, "obcy": obcy, "nauczone": False})
            zapisz_baze(baza_slowek)
            messagebox.showinfo("Sukces", f"Dodano: {obcy} = {pl}")
            self.wstaw_funkcja(None) # Przywróć pisanie do okna głównego
            self.odswiez_callback()
            self.destroy()
        else:
            messagebox.showwarning("Błąd", "Wypełnij oba pola!")

class AplikacjaNauka:
    def __init__(self, root):
        self.root = root
        self.root.title("Rosyjski Trener - ABC & Pisanie")
        self.root.geometry("550x700")
        
        self.tryb_nauczone = False
        self.tryb_gry = "ABC" # Domyślny tryb to ABC, można przełączyć na "PISANIE"
        self.aktualne_slowo = None
        self.poprawna_odpowiedz = ""
        self.aktywne_pole_tekstowe = None # Zapamiętuje, gdzie ma pisać rosyjska klawiatura
        
        # Pasek narzędziowy
        frame_top = tk.Frame(root)
        frame_top.pack(pady=10, fill=tk.X)
        
        tk.Button(frame_top, text="+ Dodaj słowo", command=self.otworz_dodawanie, bg="#FF9800", fg="white", font=("Arial", 10, "bold")).pack(side=tk.LEFT, padx=15)
        
        self.btn_tryb_gry = tk.Button(frame_top, text="Metoda: Wybór ABC", command=self.przelacz_tryb_gry, bg="#009688", fg="white", font=("Arial", 10, "bold"))
        self.btn_tryb_gry.pack(side=tk.LEFT, padx=15)
        
        self.btn_baza = tk.Button(frame_top, text="Pula: Nauka", command=self.przelacz_baze, bg="#E0E0E0", font=("Arial", 9, "bold"))
        self.btn_baza.pack(side=tk.RIGHT, padx=15)
        
        self.lbl_staty = tk.Label(root, text="Do nauki: 0 | Opanowane: 0", font=("Arial", 10, "italic"))
        self.lbl_staty.pack(pady=5)
        
        # Sekcja zadania
        self.lbl_instrukcja = tk.Label(root, text="...", font=("Arial", 11), fg="#666666")
        self.lbl_instrukcja.pack(pady=5)
        
        self.label_glowna = tk.Label(root, text="...", font=("Arial", 26, "bold"), fg="#1565C0")
        self.label_glowna.pack(pady=10)
        
        # --- KONTROLKI DLA TRYBU ABC ---
        self.frame_abc = tk.Frame(root)
        self.warianty_przyciski = []
        for i in range(3):
            btn = tk.Button(self.frame_abc, text="", font=("Arial", 12), width=35, height=2, bg="#f8f9fa",
                            command=lambda idx=i: self.sprawdz_wybor(idx))
            btn.pack(pady=4)
            self.warianty_przyciski.append(btn)
            
        # --- KONTROLKI DLA TRYBU PISANIA ---
        self.frame_pisanie = tk.Frame(root)
        self.entry_pisanie = tk.Entry(self.frame_pisanie, font=("Arial", 16), width=25, justify="center")
        self.entry_pisanie.pack(pady=5)
        self.entry_pisanie.bind("<Return>", lambda event: self.sprawdz_pisanie())
        
        self.btn_sprawdz_pisanie = tk.Button(self.frame_pisanie, text="Sprawdź (Enter)", command=self.sprawdz_pisanie, bg="#4CAF50", fg="white", font=("Arial", 11, "bold"), width=15)
        self.btn_sprawdz_pisanie.pack(pady=5)
        
        # --- STAŁA KLAWIATURA ROSYJSKA (Na dole ekranu) ---
        frame_dolny = tk.LabelFrame(root, text=" Klawiatura rosyjska (Cyrylica) ", font=("Arial", 9, "bold"), padx=10, pady=10)
        frame_dolny.pack(side=tk.BOTTOM, fill=tk.X, padx=15, pady=15)
        
        uklad_liter = [
            ['Й', 'Ц', 'У', 'К', 'Е', 'Н', 'Г', 'Ш', 'Щ', 'З', 'Х', 'Ъ'],
            ['Ф', 'Ы', 'В', 'А', 'П', 'Р', 'О', 'Л', 'Д', 'Ж', 'Э'],
            ['Я', 'Ч', 'С', 'М', 'И', 'Т', 'Ь', 'Б', 'Ю', 'Ё']
        ]
        
        for wiersz in uklad_liter:
            frame_wiersz = tk.Frame(frame_dolny)
            frame_wiersz.pack()
            for litera in wiersz:
                btn = tk.Button(frame_wiersz, text=litera.lower(), width=3, height=1, font=("Arial", 11),
                                command=lambda l=litera.lower(): self.wstaw_litere(l))
                btn.pack(side=tk.LEFT, padx=1, pady=1)
                
        frame_kontrolne = tk.Frame(frame_dolny)
        frame_kontrolne.pack(pady=4)
        tk.Button(frame_kontrolne, text="Spacja", width=15, command=lambda: self.wstaw_litere(" ")).pack(side=tk.LEFT, padx=5)
        tk.Button(frame_kontrolne, text="Cofnij (←)", width=10, bg="#ffc107", command=self.cofnij_litere).pack(side=tk.LEFT, padx=5)
        
        # Ustawienie domyślnego pisania na okno gry
        self.ustaw_aktywne_pole(self.entry_pisanie)
        
        self.losuj_pytanie()

    def ustaw_aktywne_pole(self, pole):
        # Pomaga sterować klawiaturą, żeby pisała w oknie gry LUB w okienku dodawania
        if pole is not None:
            self.aktywne_pole_tekstowe = pole
        else:
            self.aktywne_pole_tekstowe = self.entry_pisanie

    def wstaw_litere(self, litera):
        if self.aktywne_pole_tekstowe:
            self.aktywne_pole_tekstowe.insert(tk.END, litera)
            
    def cofnij_litere(self):
        if self.aktywne_pole_tekstowe:
            tekst = self.aktywne_pole_tekstowe.get()
            if tekst:
                self.aktywne_pole_tekstowe.delete(len(tekst)-1, tk.END)

    def otworz_dodawanie(self):
        OknoDodawania(self.root, self.losuj_pytanie, self.ustaw_aktywne_pole)

    def przelacz_tryb_gry(self):
        if self.tryb_gry == "ABC":
            self.tryb_gry = "PISANIE"
            self.btn_tryb_gry.config(text="Metoda: Wpisywanie", bg="#9C27B0")
        else:
            self.tryb_gry = "ABC"
            self.btn_tryb_gry.config(text="Metoda: Wybór ABC", bg="#009688")
        self.losuj_pytanie()

    def przelacz_baze(self):
        self.tryb_nauczone = not self.tryb_nauczone
        if self.tryb_nauczone:
            self.btn_baza.config(text="Pula: Powtórka", bg="#795548", fg="white")
        else:
            self.btn_baza.config(text="Pula: Nauka", bg="#E0E0E0", fg="black")
        self.losuj_pytanie()

    def losuj_pytanie(self):
        wgladowe = baza_slowek.get("Rosyjski", [])
        do_nauki = [s for s in wgladowe if not s.get("nauczone", False)]
        nauczone = [s for s in wgladowe if s.get("nauczone", False)]
        
        self.lbl_staty.config(text=f"Do nauki: {len(do_nauki)} | Opanowane: {len(nauczone)}")
        pula = nauczone if self.tryb_nauczone else do_nauki
        
        if not pula:
            self.label_glowna.config(text="Brak słówek!")
            self.frame_abc.pack_forget()
            self.frame_pisanie.pack_forget()
            return
            
        self.aktualne_slowo = random.choice(pula)
        
        if self.tryb_gry == "ABC":
            # TRYB ABC: Pytamy o słowo rosyjskie, szukamy polskiego
            self.frame_pisanie.pack_forget()
            self.frame_abc.pack(pady=10)
            
            self.lbl_instrukcja.config(text="Jak po polsku znaczy słowo:")
            self.label_glowna.config(text=self.aktualne_slowo['obcy'], fg="#1565C0")
            self.poprawna_odpowiedz = self.aktualne_slowo['pl']
            
            # Przygotowanie wariantów ABC
            for btn in self.warianty_przyciski:
                btn.config(bg="#f8f9fa", state=tk.NORMAL)
                
            wszystkie_pl = list(set([s['pl'] for s in wgladowe if s['pl'] != self.poprawna_odpowiedz]))
            if len(wszystkie_pl) < 2: wszystkie_pl = ["kot", "pies", "dom"]
            zmylacze = random.sample(wszystkie_pl, 2)
            
            self.warianty = [self.poprawna_odpowiedz] + zmylacze
            random.shuffle(self.warianty)
            
            for i in range(3):
                self.warianty_przyciski[i].config(text=self.warianty[i])
                
        else:
            # TRYB PISANIA: Dajemy słowo polskie, użytkownik wpisuje rosyjskie
            self.frame_abc.pack_forget()
            self.frame_pisanie.pack(pady=10)
            
            self.lbl_instrukcja.config(text="Przetłumacz na język rosyjski:")
            self.label_glowna.config(text=self.aktualne_slowo['pl'], fg="#2E7D32")
            self.poprawna_odpowiedz = self.aktualne_slowo['obcy']
            
            self.entry_pisanie.delete(0, tk.END)
            self.entry_pisanie.config(bg="white")
            self.entry_pisanie.focus_set()
            self.ustaw_aktywne_pole(self.entry_pisanie)

    def sprawdz_wybor(self, idx):
        wybrany_tekst = self.warianty[idx]
        if wybrany_tekst == self.poprawna_odpowiedz:
            self.warianty_przyciski[idx].config(bg="#4CAF50")
            self.oznacz_jako_nauczone(True)
            self.root.after(600, self.losuj_pytanie)
        else:
            self.warianty_przyciski[idx].config(bg="#F44336")
            self.oznacz_jako_nauczone(False)
            for btn in self.warianty_przyciski:
                if btn.cget("text") == self.poprawna_odpowiedz:
                    btn.config(bg="#4CAF50")
            self.root.after(1200, self.losuj_pytanie)

    def sprawdz_pisanie(self):
        wpisane = self.entry_pisanie.get().strip().lower()
        poprawne = self.poprawna_odpowiedz.strip().lower()
        
        if wpisane == poprawne:
            self.entry_pisanie.config(bg="#C8E6C9") # Jasnozielony
            self.oznacz_jako_nauczone(True)
            self.root.after(600, self.losuj_pytanie)
        else:
            self.entry_pisanie.config(bg="#FFCDD2") # Jasnoczerwony
            self.entry_pisanie.delete(0, tk.END)
            self.entry_pisanie.insert(0, self.poprawna_odpowiedz) # Pokaż poprawną odpowiedź
            self.oznacz_jako_nauczone(False)
            self.root.after(1500, self.losuj_pytanie)

    def oznacz_jako_nauczone(self, status):
        if status:
            if not self.aktualne_slowo.get("nauczone", False):
                self.aktualne_slowo["nauczone"] = True
                zapisz_baze(baza_slowek)
        else:
            if self.aktualne_slowo.get("nauczone", False):
                self.aktualne_slowo["nauczone"] = False
                zapisz_baze(baza_slowek)

if __name__ == "__main__":
    root = tk.Tk()
    app = AplikacjaNauka(root)
    root.mainloop()