const links = document.querySelectorAll(".sidebar a");

links.forEach(link => {
    link.addEventListener("click", e => {
        e.preventDefault();
        const target = document.querySelector(link.getAttribute("href"));
        target.scrollIntoView({ behavior: "smooth" });
    });
});

window.addEventListener("scroll", () => {
    let current = "";

    document.querySelectorAll("section").forEach(section => {
        const top = section.offsetTop - 100;
        if (scrollY >= top) current = section.id;
    });

    links.forEach(link => {
        link.style.color = "#aaa";
        if (link.getAttribute("href") === "#" + current) {
            link.style.color = "#ff8c00";
        }
    });
});
