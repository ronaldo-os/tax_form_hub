if (/^\/invoices\/\d+$/.test(location.pathname)) {
    $(document).on('click', '#download_button', function () {
        const invoice = document.getElementById("invoice_card");

        const opt = {
        margin:       [8, 8, 8, 8], // top, left, bottom, right (in pt)
        filename:     'invoice.pdf',
        image:        { type: 'jpeg', quality: 0.98 },
        html2canvas:  { scale: 2, useCORS: true },
        jsPDF:        { unit: 'pt', format: 'a4', orientation: 'portrait' }
        };

        html2pdf().set(opt).from(invoice).save();
    });
}