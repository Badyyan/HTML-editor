// Aurora demo interactions
const button = document.getElementById("cta");
let clicks = 0;

button.addEventListener("click", () => {
    clicks += 1;
    button.textContent = clicks === 1
        ? "Nice! Edit me in the editor →"
        : `Clicked ${clicks} times`;
});
