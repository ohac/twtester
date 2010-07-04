$(function(){
  $('.reply').click(function(){
    var href = $(this).attr('href');
    var str = href.split('&');
    var uid = str[0].split('=')[1];
    var tid = str[1].split('=')[1];
    $('#tweet').val(uid + ' ');
    $('#replyto').val(tid);
    $('#tweet').focus();
    return false;
  });
});
