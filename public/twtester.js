$(function(){
  $('.reply').click(function(){
    var href = $(this).attr('href');
    var str = href.split('&');
    var st = str[0].split('=')[1];
    var tid = str[1].split('=')[1];
    var uid = str[2].split('=')[1];
    $('#tweet').val(st + ' ');
    $('#replytoid').val(tid);
    $('#replyto').val(uid);
    $('#tweet').focus();
    return false;
  });
  var since_id = $('#since_id').text();
  var poll = function() {
    $.get('/', { since_id: since_id }, function(data) {
      var num = $('#num_of_tw', data).text();
      if (num > 0) {
        var refresh = $('#refresh');
        refresh.html(num + ' new tweets.');
        refresh.unbind('click');
        refresh.click(function() {
          location.href = '/';
        });
        document.title = '(' + num + ') twtester';
      }
    });
    setTimeout(poll, 10000);
  };
  setTimeout(poll, 10000);
});
