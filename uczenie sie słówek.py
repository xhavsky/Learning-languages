import tkinter as tk
from tkinter import messagebox
import random
import json
import os

# Wymuszenie szukania pliku dokładnie w tym samym folderze co skrypt
KATALOG_PROGRAMU = os.path.dirname(os.path.abspath(__file__))
PLIK_BAZY = os.path.join(KATALOG_PROGRAMU, "baza.json")

baza_domyslna = {
    "Angielski": [
        {"pl": "być", "obcy": "to be", "nauczone": False},
        {"pl": "mieć", "obcy": "to have", "nauczone": False},
        {"pl": "Dziękuję", "obcy": "Thank you", "nauczone": False}
    ],
    "Hiszpański": [
        {"pl": "być (trvale)", "obcy": "ser", "nauczone": False},
        {"pl": "mieć", "obcy": "tener", "nauczone": False},
        {"pl": "Dziękuję", "obcy": "Gracias", "nauczone": False}
    ],
    "Rosyjski (zapis fonetyczny)": [
        {"pl": "być", "obcy": "byt", "nauczone": False},
        {"pl": "mieć", "obcy": "imiet", "nauczone": False},
        {"pl": "Dziękuję", "obcy": "Spasibo", "nauczone": False}
    ]
}

def wczytaj_baze():
    if os.path.exists(PLIK_BAZY):
        try:
            with open(PLIK_BAZY, "r", encoding="utf-8") as f:
                dane = json.load(f)
                if dane and isinstance(dane, dict):
                    return dane
        except Exception:
            return baza_domyslna
    return baza_domyslna

def zapisz_baze(baza):
    try:
        with open(PLIK_BAZY, "w", encoding="utf-8") as f:
            json.dump(baza, f, ensure_ascii=False, indent=4)
    except Exception as e:
        messagebox.showerror("Błąd zapisu", f"Brak uprawnień do zapisu pliku baza.json!\nSpróbuj uruchomić program jako Administrator.\nSzczegóły: {e}")

baza_slowek = wczytaj_baze()

class OknoDodawania(tk.Toplevel):
    def __init__(self, parent, odswiez_callback):
        super().__init__(parent)
        self.title("Dodaj nowe słowo / czasownik")
        self.geometry("300x250")
        self.odswiez_callback = odswiez_callback
        
        tk.Label(self, text="Wybierz język:", font=("Arial", 10)).pack(pady=5)
        self.wybrany_jezyk = tk.StringVar(value=list(baza_slowek.keys())[0])
        tk.OptionMenu(self, self.wybrany_jezyk, *baza_slowek.keys()).pack()
        
        tk.Label(self, text="Słowo po polsku:", font=("Arial", 10)).pack(pady=5)
        self.entry_pl = tk.Entry(self, font=("Arial", 10), width=25)
        self.entry_pl.pack()
        
        tk.Label(self, text="Tłumaczenie:", font=("Arial", 10)).pack(pady=5)
        self.entry_obcy = tk.Entry(self, font=("Arial", 10), width=25)
        self.entry_obcy.pack()
        
        tk.Button(self, text="Zapisz na stałe", command=self.zapisz, bg="#2196F3", fg="white", font=("Arial", 10, "bold")).pack(pady=15)
        
    def zapisz(self):
        pl = self.entry_pl.get().strip()
        obcy = self.entry_obcy.get().strip()
        jezyk = self.wybrany_jezyk.get()
        
        if pl and obcy:
            if jezyk not in baza_slowek:
                baza_slowek[jezyk] = []
            baza_slowek[jezyk].append({"pl": pl, "obcy": obcy, "nauczone": False})
            zapisz_baze(baza_slowek)
            messagebox.showinfo("Sukces", f"Zapisano słówko na stałe do bazy!")
            self.odswiez_callback()
            self.destroy()
        else:
            messagebox.showwarning("Błąd", "Wypełnij oba pola!")

class AplikacjaNauka:
    def __init__(self, root):
        self.root = root
        self.root.title("Dialectium")
        self.root.geometry("480x450")
        
        self.jezyk = "Angielski"
        self.tryb_nauczone = False
        self.aktualne_slowo = None
        
        tk.Label(root, text="Wybierz język:", font=("Arial", 10)).pack(pady=2)
        self.opcja_jezyka = tk.StringVar(value="Angielski")
        menu = tk.OptionMenu(root, self.opcja_jezyka, *baza_slowek.keys(), command=self.zmien_jezyk)
        menu.pack()
        
        tk.Button(root, text="+ Dodaj nowe słowo do bazy", command=self.otworz_dodawanie, bg="#FF9800", fg="white", font=("Arial", 9, "bold")).pack(pady=10)
        
        self.btn_tryb = tk.Button(root, text="Tryb: Nauka (aktywne słówka)", command=self.przelacz_tryb, bg="#E0E0E0", font=("Arial", 9, "bold"))
        self.btn_tryb.pack(pady=5)
        
        self.lbl_staty = tk.Label(root, text="Do nauki: 0 | Opanowane: 0", font=("Arial", 9, "italic"))
        self.lbl_staty.pack()
        
        self.label_pytanie = tk.Label(root, text="", font=("Arial", 14, "bold"), fg="#333333")
        self.label_pytanie.pack(pady=20)
        
        self.entry_odpowiedz = tk.Entry(root, font=("Arial", 13), width=25, justify="center")
        self.entry_odpowiedz.pack(pady=5)
        self.entry_odpowiedz.bind("<Return>", lambda event: self.sprawdz_odpowiedz())
        self.entry_odpowiedz.focus_set()
        
        tk.Button(root, text="Sprawdź (Enter)", command=self.sprawdz_odpowiedz, bg="#4CAF50", fg="white", font=("Arial", 11, "bold"), width=15).pack(pady=10)
        
        self.losuj_slowo()

    def otworz_dodawanie(self):
        OknoDodawania(self.root, self.losuj_slowo)

    def zmien_jezyk(self, wybrany_jezyk):
        self.jezyk = wybrany_jezyk
        self.losuj_slowo()

    def przelacz_tryb(self):
        self.tryb_nauczone = not self.tryb_nauczone
        if self.tryb_nauczone:
            self.btn_tryb.config(text="Tryb: Powtórka (słówka nauczone)", bg="#9C27B0", fg="white")
        else:
            self.btn_tryb.config(text="Tryb: Nauka (aktywne słówka)", bg="#E0E0E0", fg="black")
        self.losuj_slowo()

    def losuj_slowo(self):
        self.entry_odpowiedz.delete(0, tk.END)
        
        wgladowe = baza_slowek.get(self.jezyk, [])
        do_nauki = [s for s in wgladowe if not s.get("nauczone", False)]
        nauczone = [s for s in wgladowe if s.get("nauczone", False)]
        
        self.lbl_staty.config(text=f"Do nauki: {len(do_nauki)} | Opanowane: {len(nauczone)}")
        
        pula = nauczone if self.tryb_nauczone else do_nauki
        
        if not pula:
            if self.tryb_nauczone:
                self.label_pytanie.config(text="Brak słówek w puli nauczonych.\nRozwiązuj testy w trybie nauki!")
            else:
                self.label_pytanie.config(text="Gratulacje! Znasz już wszystkie słowa.\nPrzełącz tryb na powtórki.")
            self.aktualne_slowo = None
            return
            
        self.aktualne_slowo = random.choice(pula)
        self.label_pytanie.config(text=f"Jak przetłumaczysz:\n\"{self.aktualne_slowo['pl']}\"?")

    def sprawdz_odpowiedz(self):
        if not self.aktualne_slowo:
            return
            
        user_input = self.entry_odpowiedz.get().strip().lower()
        poprawna = self.aktualne_slowo['obcy'].strip().lower()
        
        if user_input == poprawna:
            messagebox.showinfo("Brawo!", "Poprawna odpowiedź!")
            if not self.aktualne_slowo.get("nauczone", False):
                self.aktualne_slowo["nauczone"] = True
                zapisz_baze(baza_slowek)
            self.losuj_slowo()
        else:
            messagebox.showerror("Błąd", f"Niestety nie.\n\nPoprawna odpowiedź to:\n{self.aktualne_slowo['obcy']}")
            if self.aktualne_slowo.get("nauczone", False):
                self.aktualne_slowo["nauczone"] = False
                zapisz_baze(baza_slowek)
                messagebox.showinfo("Informacja", "Słówko wróciło do puli słów nieopanowanych.")
            self.losuj_slowo()

if __name__ == "__main__":
    root = tk.Tk()
    app = AplikacjaNauka(root)
    root.mainloop()