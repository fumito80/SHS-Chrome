const canvas = document.getElementById('myCanvas');
canvas.setAttribute('width', 19);
canvas.setAttribute('height', 19);
const ctx = canvas.getContext('2d');

ctx.beginPath();
ctx.globalCompositeOperation = "source-over"
ctx.fillStyle = "rgba(0, 0, 0, 0.4)";
ctx.lineJoin = 'round';
ctx.moveTo(10, 0);
ctx.arcTo(19, 0, 19, 10, 2);
ctx.arcTo(19, 19, 10, 19, 2);
ctx.arcTo(0, 19, 0, 10, 2);
ctx.arcTo(0, 0, 10, 0, 2);
ctx.closePath();
ctx.fill();

ctx.beginPath();
ctx.globalCompositeOperation = "destination-out"
ctx.fillStyle = 'black';
ctx.fillRect(3, 3, 13, 5);
ctx.fillRect(3, 11, 13, 5);

ctx.globalCompositeOperation = "source-over"
ctx.fillStyle = '#ff7600';
ctx.fillRect(3, 3, 13, 5);
ctx.fillStyle = '#ff0';
ctx.fillRect(3, 11, 13, 5);

const dataURL = canvas.toDataURL();
document.getElementById('canvasImg').src = dataURL;
