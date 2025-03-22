import os
import pygame
import threading
import socketio
from flask import Flask, render_template, request
from flask_socketio import SocketIO
from tkinter import Tk, Button, Label


HOST = '0.0.0.0'
PORT = 5000
IMAGE_DIR = "server/imagens_capturadas"
os.makedirs(IMAGE_DIR, exist_ok=True)


app = Flask(__name__)
socketio = SocketIO(app, cors_allowed_origins="*")

pygame.mixer.init()
ALARME_SOM = os.path.join(os.path.dirname(__file__), "airton.mp3")


try:
    pygame.mixer.music.load(ALARME_SOM)
    print("✅ Arquivo de som carregado com sucesso!")
except pygame.error as e:
    print(f"❌ Erro ao carregar o arquivo: {e}")


alarm_active = False


class ServidorGUI:
    def __init__(self, root):
        self.root = root
        self.root.title("Servidor de Monitoramento")
        
        self.label_status = Label(root, text="Aguardando alerta...", font=("Arial", 14))
        self.label_status.pack(pady=10)

        self.btn_parar = Button(root, text="🔇 Parar Alarme", command=self.parar_alarme, state="disabled")
        self.btn_parar.pack(pady=5)

        threading.Thread(target=self.iniciar_servidor, daemon=True).start()

    def iniciar_servidor(self):
        print(f"🚀 Servidor rodando em http://localhost:{PORT}")
        socketio.run(app, host=HOST, port=PORT, debug=False, allow_unsafe_werkzeug=True)

    def ativar_alarme(self):

        global alarm_active
        if not alarm_active:
            alarm_active = True
            self.label_status.config(text="🚨 Alarme Ativado!")
            pygame.mixer.music.load(ALARME_SOM)
            pygame.mixer.music.play(-1) 
            self.btn_parar.config(state="normal")
            print("🔊 Alarme tocando...")

    def parar_alarme(self):

        global alarm_active
        if alarm_active:
            alarm_active = False
            pygame.mixer.music.stop()
            self.label_status.config(text="Aguardando alerta...")
            self.btn_parar.config(state="disabled")
            socketio.emit('PARAR_ALARME')



@app.route('/')
def home():

    return '''
    <html>
    <head><title>Servidor de Monitoramento</title></head>
    <body>
        <h1>Monitoramento de Segurança</h1>
        <button onclick="pararAlarme()">🔇 Parar Alarme</button>
        <script>
            function pararAlarme() {
                fetch('/parar', { method: 'POST' });
            }
        </script>
    </body>
    </html>
    '''

@app.route('/parar', methods=['POST'])
def parar_alarme_web():

    gui.parar_alarme()
    return "Alarme desligado!", 200

@socketio.on('connect')
def handle_connect():

    print("📲 Cliente conectado!")

@socketio.on('ALERTA')
def handle_alerta():

    print("🚨 ALERTA RECEBIDO! Enviando comando para o celular...")
    gui.ativar_alarme()

@socketio.on('imagem')
def handle_image(image_data):

    image_path = os.path.join(IMAGE_DIR, "intruso.jpg")
    with open(image_path, "wb") as img_file:
        img_file.write(image_data)
    print(f"📸 Imagem salva em {image_path}")

root = Tk()
gui = ServidorGUI(root)
root.mainloop()
