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
});
