var ws;
var game_id;
var gameover = false;

function update_score(data) {
    console.log("updating: ", data)
    $("#board-score span").html(data.score);
    $("#board-flags span").html(data.flags);
}

function draw(html) {
    $("#board").html(html);
    $("#board-msg").html("");
    $(".cell").on("click", function(event){
        var row_id, col_id;
        [row_id, col_id] = this.id.split("-", 2).map(function(chunk) {
            return parseInt(chunk.slice(3));
        });
        send({type: "sweep", "x": col_id, "y": row_id});
    });
    $(".cell").on("contextmenu", function(event){
        var row_id, col_id;
        [row_id, col_id] = this.id.split("-", 2).map(function(chunk) {
            return parseInt(chunk.slice(3));
        });
        send({type: "flag", "x": col_id, "y": row_id});
        return false;
    });
}

function disconnected(should_i_reconnect) {
    if (should_i_reconnect) {
        $("#board-msg").html("<h2>¡Disconnected! Reconnecting...</h2>");
        setTimeout(function(){ connect(); }, 1000);
    } else {
        $("#board-msg").html("<h2>¡Disconnected!</h2>");
    }
}

function send(message) {
    console.log("send: ", message);
    ws.send(JSON.stringify(message));
};

function connect() {
    const hostname = document.location.href.split("/", 3)[2];
    if (ws) {
        ws.close();
    }
    var schema = (location.href.split(":")[0] == "https") ? "wss" : "ws";
    ws = new WebSocket(schema + "://" + hostname + "/websession");
    ws.onopen = function(){
        console.log("connected!");
        if (game_id) {
            send({type: "join", id: game_id})
        } else {
            send({type: "create"})
        }
        send({type: "show"});
    };
    ws.onerror = function(message){
        console.error("onerror", message);
        disconnected(false);
    };
    ws.onclose = function() {
        if (!gameover) {
            console.error("onclose");
            disconnected(true);
        }
    }
    ws.onmessage = function(message){
        console.log("Got message", message.data);
        var data = JSON.parse(message.data);

        switch(data.type) {
            case "gameover":
                gameover = true;
                ws.close();
                $("#board-msg").html("<h2>GAME OVER!</h2>");
                break;
            case "win":
                gameover = true;
                ws.close();
                $("#board-msg").html("<h2>YOU WIN!</h2>");
                break;
            case "draw":
                draw(data.html);
                update_score(data);
                break;
            case "id":
                game_id = data.id;
                break;
            case "vsn":
                $("#vsn").html("v" + data.vsn);
                break;
            case "tick":
                $("#board-time span").html(data.time);
                break;
        }
    };
}

$(document).ready(function(){
    connect();
    $("#board-restart").on("click", function(event){
        send({type: "stop"});
        location.reload(true);
    });
});
