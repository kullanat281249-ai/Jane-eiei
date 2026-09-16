<!DOCTYPE html>
<html lang="th">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Math Balloon Pop Game</title>
    <style>
        body {
            margin: 0;
            padding: 0;
            background-color: #FFB6C1; /* สีชมพูสดใส */
            font-family: 'Tahoma', sans-serif;
            user-select: none;
            overflow: hidden;
        }
        #game-container {
            width: 100vw;
            height: 100vh;
            position: relative;
            box-sizing: border-box;
        }
        /* Dashboard ด้านบน */
        #header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 15px 30px;
            background: rgba(255, 255, 255, 0.4);
            font-size: 28px;
            font-weight: bold;
            color: #000;
        }
        #question-box {
            text-align: center;
            font-size: 48px;
            font-weight: 900;
            color: #000;
            margin-top: 10px;
        }
        /* โซนลูกโป่ง */
        #balloon-area {
            width: 100%;
            height: calc(100vh - 150px);
            position: relative;
        }
        .balloon {
            width: 140px;
            height: 160px;
            border-radius: 50% 50% 50% 50% / 40% 40% 60% 60%;
            position: absolute;
            display: flex;
            justify-content: center;
            align-items: center;
            font-size: 44px;
            font-weight: bold;
            color: #000;
            cursor: pointer;
            box-shadow: inset -10px -10px 20px rgba(0,0,0,0.2), 0 10px 15px rgba(0,0,0,0.15);
            animation: float 3s ease-in-out infinite alternate;
        }
        .balloon::after {
            content: '';
            position: absolute;
            bottom: -12px;
            width: 0;
            height: 0;
            border-left: 8px solid transparent;
            border-right: 8px solid transparent;
            border-bottom: 12px solid inherit;
        }
        /* สุ่มอนิเมชันลอยขึ้นลง */
        @keyframes float {
            0% { transform: translateY(0px); }
            100% { transform: translateY(-30px); }
        }
        /* เอฟเฟกต์สีผิด */
        .wrong-flash {
            background-color: #FF0000 !important;
            animation: shake 0.3s !important;
        }
        @keyframes shake {
            0%, 100% { transform: translateX(0); }
            25% { transform: translateX(-15px); }
            75% { transform: translateX(15px); }
        }
        /* Popup ตอนจบ */
        #modal {
            display: none;
            position: fixed;
            top: 0; left: 0; width: 100%; height: 100%;
            background: rgba(0,0,0,0.6);
            justify-content: center;
            align-items: center;
        }
        .modal-content {
            background: white;
            padding: 40px;
            border-radius: 20px;
            text-align: center;
            box-shadow: 0 10px 25px rgba(0,0,0,0.3);
        }
        .btn-restart {
            margin-top: 20px;
            padding: 15px 30px;
            font-size: 24px;
            background-color: #FF1493;
            color: white;
            border: none;
            border-radius: 10px;
            cursor: pointer;
            font-weight: bold;
        }
    </style>
</head>
<body>

<div id="game-container">
    <div id="header">
        <div>คะแนน: <span id="score">0</span></div>
        <div>เวลา: <span id="timer">60</span> วิ</div>
    </div>
    <div id="question-box"><span id="math-question">8 + 5 = ?</span></div>
    <div id="balloon-area"></div>
</div>

<div id="modal">
    <div class="modal-content">
        <h1 style="font-size: 36px; color: #FF1493;">หมดเวลาแล้ว!</h1>
        <p style="font-size: 28px;">คะแนนรวมของคุณคือ: <b id="final-score" style="color: #000;">0</b> คะแนน</p>
        <button class="btn-restart" onclick="startGame()">เล่นอีกครั้ง</button>
    </div>
</div>

<script>
    let score = 0;
    let timeLeft = 60;
    let timerInterval;
    let correctAnswer = 0;
    const colors = ['#FF4D4D', '#1E90FF', '#32CD32', '#FFD700'];

    function generateQuestion() {
        const isAddition = Math.random() > 0.5;
        let num1 = Math.floor(Math.random() * 10) + 1;
        let num2 = Math.floor(Math.random() * 10) + 1;
        
        if (isAddition) {
            correctAnswer = num1 + num2;
            document.getElementById('math-question').innerText = `${num1} + ${num2} = ?`;
        } else {
            if (num1 < num2) [num1, num2] = [num2, num1]; // ป้องกันผลลัพธ์ติดลบ
            correctAnswer = num1 - num2;
            document.getElementById('math-question').innerText = `${num1} - ${num2} = ?`;
        }
        spawnBalloons();
    }

    function spawnBalloons() {
        const area = document.getElementById('balloon-area');
        area.innerHTML = '';
        
        // สร้างคำตอบ 4 ตัว (ถูก 1 หลอก 3)
        let options = [correctAnswer];
        while (options.length < 4) {
            let wrong = correctAnswer + (Math.floor(Math.random() * 7) - 3);
            if (wrong >= 0 && !options.includes(wrong)) {
                options.push(wrong);
            }
        }
        options.sort(() => Math.random() - 0.5); // สลับลำดับ

        // กำหนดตำแหน่งลูกโป่ง 4 ลูกไม่ให้ทับกัน
        const positions = [
            { top: '20%', left: '15%' },
            { top: '15%', left: '60%' },
            { top: '55%', left: '25%' },
            { top: '50%', left: '70%' }
        ];

        options.forEach((val, idx) => {
            const balloon = document.createElement('div');
            balloon.className = 'balloon';
            balloon.style.backgroundColor = colors[idx];
            balloon.style.top = positions[idx].top;
            balloon.style.left = positions[idx].left;
            balloon.innerText = val;
            
            // สุ่มเวลาอนิเมชันไม่ให้พร้อมกัน
            balloon.style.animationDuration = (2.5 + Math.random()) + 's';

            balloon.onclick = function() {
                if (val === correctAnswer) {
                    score += 10;
                    document.getElementById('score').innerText = score;
                    generateQuestion();
                } else {
                    timeLeft = Math.max(0, timeLeft - 5);
                    document.getElementById('timer').innerText = timeLeft;
                    balloon.classList.add('wrong-flash');
                    setTimeout(() => balloon.classList.remove('wrong-flash'), 400);
                }
            };
            area.appendChild(balloon);
        });
    }

    function startGame() {
        score = 0;
        timeLeft = 60;
        document.getElementById('score').innerText = score;
        document.getElementById('timer').innerText = timeLeft;
        document.getElementById('modal').style.display = 'none';
        
        generateQuestion();
        
        clearInterval(timerInterval);
        timerInterval = setInterval(() => {
            timeLeft--;
            document.getElementById('timer').innerText = timeLeft;
            if (timeLeft <= 0) {
                clearInterval(timerInterval);
                endGame();
            }
        }, 1000);
    }

    function endGame() {
        document.getElementById('final-score').innerText = score;
        document.getElementById('modal').style.display = 'flex';
    }

    // เริ่มเกมทันทีที่โหลดหน้าเว็บ
    startGame();
</script>
</body>
</html>
