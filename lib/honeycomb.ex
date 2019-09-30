defmodule Honeycomb do
  use GenServer

  # DECISION : GOSSIP vs PUSH_SUM
  def init([x,numberOfNodes, is_push_sum]) do
    neighbors = get_neighbors(x,numberOfNodes)
    # IO.puts Enum.at(neighbors,1)
    case is_push_sum do
      0 -> {:ok, [Active,0,0, numberOfNodes, x | neighbors] } #[ status, rec_count, sent_count, n, self_number_id | neighbors ]
      1 -> {:ok, [Active,0, 0, 0, 0, x, 1, numberOfNodes, x| neighbors] } #[status, rec_count,streak,prev_s_w,to_terminate, s, w, n, self_number_id | neighbors ]
    end
  end

    # GOSSIP - RECIEVE Main
  def handle_cast({:message_gossip, _received}, [status,count,sent,numberOfNodes,x| neighbors ] =state ) do
    length = round(Float.ceil(:math.sqrt(numberOfNodes)))
    i = rem(x-1,length) + 1
    j = round(Float.floor(((x-1)/length))) + 1
    case count < 200 do
      true ->  GenServer.cast(Master,{:received, [{i,j}]})
               gossip(x,neighbors,self(),numberOfNodes,i,j)
      false -> GenServer.cast(Master,{:hibernated, [{i,j}]})
    end
    {:noreply,[status,count+1 ,sent,numberOfNodes, x  | neighbors]}
  end

  # GOSSIP  - SEND Main
  def gossip(x,neighbors,pid, n,i,j) do
    the_one = selected_neighbor(neighbors)
    GenServer.cast(the_one, {:message_gossip, :_sending})
    # case GenServer.call(the_one,:is_active) do
      # Active -> GenServer.cast(the_one, {:message_gossip, :_sending})
      # ina_xy -> GenServer.cast(Master,{:neighbors_inactive, ina_xy})
      #           new_neighbor = GenServer.call(Master,:handle_node_failure)
      #           GenServer.cast(self(),{:remove_neighbor,the_one})
      #           GenServer.cast(self(),{:add_new_neighbor,new_neighbor})
      #           GenServer.cast(new_neighbor,{:add_new_neighbor,node_name(x)})
      #           GenServer.cast(self(),{:retry_gossip,{pid,i,j}})
    # end
  end

      # PUSHSUM - RECIEVE Main
  def handle_cast({:message_push_sum, {rec_s, rec_w} }, [status,count,streak,prev_s_w,term, s ,w, n, x | neighbors ] = state ) do
    length = round(Float.ceil(:math.sqrt(n)))
    i = rem(x-1,length) + 1
    j = round(Float.floor(((x-1)/length))) + 1
    GenServer.cast(Master,{:received, [{i,j}]})
      case abs(((s+rec_s)/(w+rec_w))-prev_s_w) < :math.pow(10,-10) do
        false ->push_sum(x,(s+rec_s)/2,(w+rec_w)/2,neighbors,self(),i,j)
                {:noreply,[status,count+1, 0, (s+rec_s)/(w+rec_w), term, (s+rec_s)/2, (w+rec_w)/2, n, x  | neighbors]}
        true ->
          case streak + 1 == 3 do
            true ->  GenServer.cast(Master,{:hibernated, [{i,j}]})
                      {:noreply,[status,count+1, streak+1, (s+rec_s)/(w+rec_w), 1, (s+rec_s), (w+rec_w), n, x  | neighbors]}
            false -> push_sum(x,(s+rec_s)/2, (w+rec_w)/2, neighbors, self(), i, j)
                      {:noreply,[status,count+1, streak+1, (s+rec_s)/(w+rec_w), 0, (s+rec_s)/2, (w+rec_w)/2, n, x  | neighbors]}
          end
      end
  end

  # PUSHSUM  - SEND MAIN
  def push_sum(x,s,w,neighbors,pid ,i,j) do
    the_one = selected_neighbor(neighbors)
    GenServer.cast(the_one,{:message_push_sum,{ s,w}})
    # case GenServer.call(the_one,:is_active) do
    #   Active -> GenServer.cast(the_one,{:message_push_sum,{ s,w}})
    #   ina_xy ->  GenServer.cast(Master,{:node_inactive, ina_xy})
    #             new_neighbor = GenServer.call(Master,:handle_node_failure)
    #             GenServer.cast(self(),{:remove_neighbor,the_one})
    #             GenServer.cast(self(),{:add_new_neighbor,new_neighbor})
    #             GenServer.cast(new_neighbor,{:add_new_neighbor,node_name(x)})
    #             GenServer.cast(self(),{:retry_push_sum,{x,s,w,pid,i,j}})
    # end
  end

  def get_neighbors(self,n) do
    elementsPerRow = round(:math.sqrt(n))
    neighbors =[getFirstNeighbor(self,elementsPerRow),getSecondNeighbor(self,elementsPerRow,n), getThirdNeighbor(self,elementsPerRow,n)]
    filteredNeighbors = Enum.filter(neighbors, fn(x) -> x != nil end)
    # IO.puts filteredNeighbors
    neighborIds = Enum.map(filteredNeighbors, fn(x) -> node_name(x) end)
    # IO.inspect Enum.at(neighbors,0)
    neighborIds

  end

  def getFirstNeighbor(x,elemPerRow) do
    if (x-elemPerRow) >= 1 do
      x-elemPerRow
    end
  end
  def getSecondNeighbor(x,elemPerRow, n) do
    if (x+elemPerRow) <= n do
      x+elemPerRow
    end
  end
  def getThirdNeighbor(x,elemPerRow, n)  do
    isLastElementInRow = rem(x,elemPerRow) == 0

    rowNumber = case isLastElementInRow do
      true -> round(div(x,round(elemPerRow)))-1
      false -> round(div(x,round(elemPerRow)))
    end

    remainder = rem(rowNumber,2)
    isXOdd = rem(x,2)
    # IO.puts("x: #{x}, elePerRow: #{elemPerRow}, n: #{n}, rownumber: #{rowNumber}, islastEl: #{isLastElementInRow} remainder: #{remainder}, isXOdd : #{isXOdd}")
    # case remainder do
    #   true -> case isXOdd && x > 1 do
    #     true -> round(x-1)
    #   end
    # end
    neighbor  = cond do
      remainder == 0 && isXOdd == 0 && x > 1 && rem(x,elemPerRow) > 1 ->
        # IO.puts "Came"
        round(x-1)
      remainder == 0 && isXOdd == 1 && x< n ->
        round(x+1)
      remainder == 1 && isXOdd == 1 && x > 1 ->
        round(x-1)
      remainder == 1 && isXOdd == 0 && x< n ->
        round(x+1)
      x == 0 || x==n || rem(x, elemPerRow) <2->
        nil
      end

    # IO.puts neighbor
    neighbor

  end

  def create_topology(numberOfNodes, is_push_sum \\ 0) do
    all_nodes =
      for x <- 1..numberOfNodes do
        name = node_name(x)
        GenServer.start_link(Honeycomb, [x,numberOfNodes, is_push_sum], name: name)
        name
      end
    GenServer.cast(Master,{:all_nodes_update,all_nodes})
  end

  def node_name(x) do
    a = x|> Integer.to_string |> String.pad_leading(7,"0")
    "Elixir.D"<>a
    |>String.to_atom
  end

  def selected_neighbor(neighbors) do
    Enum.random(neighbors)
  end

end
