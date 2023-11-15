open Mill.Type
open Mill.Arena
open Mill.Engine

(*PRETTY PRINTS*)

(*
let affiche_tour_info color phase =
    match color with
    | Black ->
        Format.printf "Le tour de BLACK\n";
        pretty_print_phase phase
    | White ->
        Format.printf "Le tour de  WHITE\n";
        pretty_print_phase phase

let print_move (m : direction_deplacement) =
    match m with
    | Up -> Format.printf "Up\n"
    | Down -> Format.printf "Down\n"
    | Right -> Format.printf "Right\n"
    | Left -> Format.printf "Left\n"
    | Up_right -> Format.printf "Up_right\n"
    | Up_left -> Format.printf "Up_left\n"
    | Down_right -> Format.printf "Down_right\n"
    | Down_left -> Format.printf "Down_left\n"

let pretty_print_list_direction l = l |> List.iter (fun a -> print_move a)

let print_cord (x, y) =
    let exit = "x :" ^ string_of_int x ^ " y :" ^ string_of_int y ^ "\n" in
    Format.printf "%s" exit

(** Function that print a board square *)
let print_square (s : square) =
    match s with
    | Color White -> Format.printf "{W}"
    | Color Black -> Format.printf "{B}"
    | Empty -> Format.printf "{ }"
    | Path H -> Format.printf "---"
    | Path V -> Format.printf " | "
    | Path DR -> Format.printf " / "
    | Path DL -> Format.printf " \\ "
    | _ -> Format.printf "   "

(** Print the board in the shell *)
let pretty_print_board (b : board) : unit =
    List.iter
      (fun l ->
        List.iter print_square l;
        Format.printf "@.")
      b;
    Format.printf "\n"

let pretty_print_phase (p : phase) =
    match p with
    | Placing -> Format.printf "Phase de placement\n"
    | Moving -> Format.printf "Phase de deplacement\n"
    | Flying -> Format.printf "Phase de flying\n"
    
    *)
(*
let show_winner color =
    match color with
    | Black -> Format.printf "Le vainqueur est BLACK"
    | White -> Format.printf "Le vainqueur est WHITE"*)
(*TEST*)

let equals_board (board1 : board) (board2 : board) : bool =
    let rec compare l1 l2 =
        match (l1, l2) with
        | [], [] -> true
        | [], _ -> false
        | _, [] -> false
        | x :: xs, y :: ys -> (
            match (x, y) with
            | Empty, Empty -> compare xs ys
            | Wall, Wall -> compare xs ys
            | Path d, Path g when d = g -> compare xs ys
            | Color c1, Color c2 when c1 = c2 -> compare xs ys
            | _ -> false)
    in
    compare (List.flatten board1) (List.flatten board2)

let equals_coordinate (c1 : coordinates) (c2 : coordinates) : bool = fst c1 = fst c2 && snd c1 = snd c2

let rec equals_list_coordinate (l1 : coordinates list) (l2 : coordinates list) : bool =
    match (l1, l2) with
    | [], [] -> true
    | [], _ -> false
    | _, [] -> false
    | x :: xs, y :: ys -> equals_coordinate x y && equals_list_coordinate xs ys

let equals_player (p1 : player) (p2 : player) : bool =
    p1.color = p2.color
    && equals_list_coordinate p1.bag p2.bag
    && p1.piece_placed = p2.piece_placed
    && p1.nb_pieces_on_board = p2.nb_pieces_on_board

let equals_end_game (game1 : end_game) (game2 : end_game) : bool =
    equals_board game1.board game2.board
    && equals_player game1.loser game2.loser
    && equals_player game1.winner game2.winner

let game_update_of_game (game : end_game) : game_update =
    if game.winner.color = White
    then
      {
        board = game.board;
        mill = false;
        player1 = game.winner;
        player2 = game.loser;
        game_is_changed = false;
        max_pieces = game.winner.piece_placed;
      }
    else
      {
        board = game.board;
        mill = false;
        player1 = game.loser;
        player2 = game.winner;
        game_is_changed = false;
        max_pieces = game.winner.piece_placed;
      }

let test_config_end_game =
    let open QCheck in
    Test.make ~count:100 ~name:"for all game : one of players can't move or has two pieces left" small_int (fun _ ->
        let randomSeed n =
            Random.self_init ();
            Random.int n
        in
        let player1 = player_random randomSeed in
        let player2 = player_random randomSeed in
        let game = arena player1 player2 Nine_mens_morris in
        let game_update = game_update_of_game game in
        cant_move game.loser game_update || game.loser.nb_pieces_on_board <= 2)

(**This test check that with the same seed, we will get the same end*)
let testSeed =
    let open QCheck in
    Test.make ~count:10 ~name:"for all seed : END gamePlayWithSeed = END gamePlayWithSeed when both seeds are the same"
      small_int (fun x ->
        Random.init x;
        let randomSeed n = Random.int n in
        let player1 = player_random randomSeed in
        let player2 = player_random randomSeed in
        let game1 = arena player1 player2 Nine_mens_morris in
        Random.init x;
        let randomSeed n = Random.int n in
        let player1 = player_random randomSeed in
        let player2 = player_random randomSeed in
        let game2 = arena player1 player2 Nine_mens_morris in
        equals_end_game game1 game2)

let square_reachable_from_coordinates (i, j) (board : board) : board =
    let rec allReachable_from_coordinates (i, j) (board : board) (acc : direction_deplacement list) =
        let new_board, _ = place_piece_on_board board (i, j) Black in
        let rec loop board (i, j) list_of_direction =
            match list_of_direction with
            | [] -> board
            | x :: xs -> (
                let coord = node_from_direction board (i, j) x in
                match coord with
                | None -> loop board (i, j) xs
                | Some c -> (
                    let square = get_square board c in
                    match square with
                    | Some Empty ->
                        let nv = allReachable_from_coordinates c board acc in
                        loop nv (i, j) xs
                    | _ -> loop board (i, j) xs))
        in
        loop new_board (i, j) acc
    in
    allReachable_from_coordinates (i, j) board [Up; Down; Right; Left; Up_right; Up_left; Down_right; Down_left]

let test_complete_board (board : board) : bool =
    let rec aux i j =
        let size = List.length board in
        if i = size && j = size
        then true
        else if j = size
        then aux (i + 1) 0
        else
          let square = get_square board (i, j) in
          match square with
          | Some Empty -> false
          | _ -> aux i (j + 1)
    in
    aux 0 0

let generate_templates =
    let open QCheck in
    Gen.oneof
      [
        Gen.return Six_mens_morris;
        Gen.return Three_mens_morris;
        Gen.return Nine_mens_morris;
        Gen.return Twelve_mens_morris;
      ]

let arbitrary_templates = QCheck.make generate_templates

let test_reachable =
    let open QCheck in
    Test.make ~count:10000 ~name:"for all board : all square are reachable"
      (triple small_int small_int arbitrary_templates) (fun (x, y, template) ->
        let board = init_board_with_template template in
        let i = x mod List.length board in
        let j = y mod List.length board in
        let square = get_square board (i, j) in
        match square with
        | Some Empty ->
            let new_board = square_reachable_from_coordinates (i, j) board in
            test_complete_board new_board
        | _ ->
            let new_board = square_reachable_from_coordinates (0, 0) board in
            test_complete_board new_board)

let player_random_dumb (random : int -> int) : player_strategie =
    (* The placing/moving strategy is here *)
    let strategie_play (game_update : game_update) (player : player) : move =
        match player.phase with
        | Placing ->
            (* We also allow the bot to go outside the board by 1 square (to make him very dumb)*)
            let i = random (List.length game_update.board + 2) - 1 in
            let j = random (List.length game_update.board + 2) - 1 in
            Placing (i, j)
        | Moving ->
            let i = random (List.length player.bag + 2) - 1 in
            let coord = List.nth player.bag i in
            let possible_move = [Up; Down; Right; Left; Up_right; Up_left; Down_right; Down_left] in
            let j = random (List.length possible_move + 2) - 1 in
            let dir = List.nth possible_move j in
            Moving (coord, dir)
        | Flying ->
            (* We also allow the bot to go outside the board by 1 square (to make him very dumb)*)
            let i = random (List.length game_update.board + 2) - 1 in
            let j = random (List.length game_update.board + 2) - 1 in
            let coord_arrive = (i, j) in
            let i = random (List.length player.bag) in
            let depart = List.nth player.bag i in
            Flying (depart, coord_arrive)
    in
    (* The removing strategy is here *)
    let strategie_remove (game_update : game_update) (player : player) : coordinates =
        let i = random (List.length (get_opponent game_update player.color).bag) in
        List.nth (get_opponent game_update player.color).bag i
    in
    { strategie_play; strategie_remove }

let test_error_player =
    let open QCheck in
    Test.make ~count:1000 ~name:"for all game : the dumb bot will never finish the game"
      (pair small_int arbitrary_templates) (fun (x, template) ->
        Random.init x;
        let randomSeed n = Random.int n in
        let player1 = player_random_dumb randomSeed in
        let player2 = player_random_dumb randomSeed in
        try
          let _ = arena player1 player2 template in
          false
        with
        | Not_Allowed _ | Invalid_Strategy _ -> true
        | _ -> false)

let () =
    let open Alcotest in
    run "TEST"
      [
        ("Test with Seed generate", [QCheck_alcotest.to_alcotest testSeed]);
        ("Test configuration end game", [QCheck_alcotest.to_alcotest test_config_end_game]);
        ("Test reachable square", [QCheck_alcotest.to_alcotest test_reachable]);
        ("Test error player", [QCheck_alcotest.to_alcotest test_error_player]);
      ]
